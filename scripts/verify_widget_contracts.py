#!/usr/bin/env python3
"""Verify the mirrored app/widget contract sources and stored payload compatibility."""

from __future__ import annotations

import argparse
import difflib
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import tempfile
from typing import Dict, Iterable, Sequence


CONTRACT_FILES = (
    "WidgetConstants.swift",
    "WidgetPlaybackState.swift",
    "WidgetTrackInfo.swift",
)
APP_CONTRACT_ROOT = Path("Fonic HiFi/Shared")
WIDGET_CONTRACT_ROOT = Path("Fonic HiFi Widget/Shared")
# Direct swiftc invocation under prerelease Xcode otherwise inherits the host OS
# as its minimum target, which can make the toolchain's standard library unloadable.
HOST_DEPLOYMENT_TARGET = "15.0"


class VerificationFailure(RuntimeError):
    """A deterministic contract-verification failure."""


def run_command(
    arguments: Sequence[str],
    *,
    environment: Dict[str, str],
    working_directory: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        list(arguments),
        cwd=working_directory,
        env=environment,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        rendered = " ".join(arguments)
        details = "\n".join(part for part in (result.stdout.strip(), result.stderr.strip()) if part)
        raise VerificationFailure(f"Command failed ({result.returncode}): {rendered}\n{details}")
    return result


def selected_swift_compiler(environment: Dict[str, str]) -> Path:
    result = run_command(
        ("/usr/bin/xcrun", "--find", "swiftc"),
        environment=environment,
    )
    compiler = Path(result.stdout.strip())
    if not compiler.is_file():
        raise VerificationFailure(f"xcrun returned an invalid Swift compiler path: {compiler}")
    return compiler


def selected_macos_sdk(environment: Dict[str, str]) -> Path:
    result = run_command(
        ("/usr/bin/xcrun", "--sdk", "macosx", "--show-sdk-path"),
        environment=environment,
    )
    sdk = Path(result.stdout.strip())
    if not sdk.is_dir():
        raise VerificationFailure(f"xcrun returned an invalid macOS SDK path: {sdk}")
    return sdk


def canonical_parse_tree(
    swiftc: Path,
    source: Path,
    *,
    environment: Dict[str, str],
) -> str:
    result = run_command(
        (str(swiftc), "-frontend", "-dump-parse", str(source)),
        environment=environment,
    )
    tree = result.stdout
    tree = tree.replace(str(source), "<contract>")
    tree = tree.replace(source.name, "<contract>")
    tree = re.sub(r"0x[0-9a-fA-F]+", "<context>", tree)
    tree = re.sub(r"range=\[[^\]]*\]", "range=[<location>]", tree)
    tree = re.sub(r"location=[^ )\]]+", "location=<location>", tree)
    tree = re.sub(r"\bline:\d+:\d+\b", "line:<location>", tree)
    tree = re.sub(r"<contract>:\d+:\d+", "<contract>:<location>", tree)
    return tree.strip()


def verify_semantic_mirrors(
    source_root: Path,
    swiftc: Path,
    *,
    environment: Dict[str, str],
) -> None:
    for filename in CONTRACT_FILES:
        app_source = source_root / APP_CONTRACT_ROOT / filename
        widget_source = source_root / WIDGET_CONTRACT_ROOT / filename
        for source in (app_source, widget_source):
            if not source.is_file():
                raise VerificationFailure(f"Missing contract source: {source}")

        app_tree = canonical_parse_tree(swiftc, app_source, environment=environment)
        widget_tree = canonical_parse_tree(swiftc, widget_source, environment=environment)
        if app_tree == widget_tree:
            continue

        difference = "\n".join(
            difflib.unified_diff(
                app_tree.splitlines(),
                widget_tree.splitlines(),
                fromfile=str(app_source),
                tofile=str(widget_source),
                lineterm="",
            )
        )
        raise VerificationFailure(f"Semantic widget contract drift in {filename}:\n{difference}")


def compile_probe(
    swiftc: Path,
    sdk: Path,
    source_root: Path,
    contract_root: Path,
    harness: Path,
    output: Path,
    module_name: str,
    module_cache: Path,
    *,
    environment: Dict[str, str],
) -> None:
    architecture = platform.machine()
    if architecture not in {"arm64", "x86_64"}:
        raise VerificationFailure(f"Unsupported macOS host architecture: {architecture}")

    sources = [str(source_root / contract_root / filename) for filename in CONTRACT_FILES]
    run_command(
        (
            str(swiftc),
            "-sdk",
            str(sdk),
            "-target",
            f"{architecture}-apple-macosx{HOST_DEPLOYMENT_TARGET}",
            "-swift-version",
            "6",
            "-parse-as-library",
            "-module-name",
            module_name,
            "-module-cache-path",
            str(module_cache),
            *sources,
            str(harness),
            "-o",
            str(output),
        ),
        environment=environment,
    )


def isolated_probe_environment(base: Dict[str, str], home: Path, temporary_root: Path) -> Dict[str, str]:
    home.mkdir(parents=True, exist_ok=True)
    environment = base.copy()
    environment["HOME"] = str(home)
    environment["CFFIXED_USER_HOME"] = str(home)
    environment["TMPDIR"] = str(temporary_root)
    return environment


def run_probe(
    executable: Path,
    command: str,
    payload_root: Path,
    *,
    environment: Dict[str, str],
) -> None:
    run_command(
        (str(executable), command, str(payload_root)),
        environment=environment,
    )


def verify_contracts(source_root: Path, fixture_root: Path, *, verbose: bool) -> None:
    script_root = Path(__file__).resolve().parent
    harness = script_root / "widget_contract_fixture_harness.swift"
    if not harness.is_file():
        raise VerificationFailure(f"Missing fixture harness: {harness}")
    if not fixture_root.is_dir():
        raise VerificationFailure(f"Missing frozen fixture directory: {fixture_root}")

    environment = os.environ.copy()
    swiftc = selected_swift_compiler(environment)
    sdk = selected_macos_sdk(environment)
    verify_semantic_mirrors(source_root, swiftc, environment=environment)
    if verbose:
        print("[PASS] mirrored_contracts_have_equivalent_parse_trees", flush=True)

    with tempfile.TemporaryDirectory(prefix="fonic-widget-contracts-") as temporary_directory:
        temporary_root = Path(temporary_directory)
        module_cache = temporary_root / "ModuleCache"
        module_cache.mkdir()
        compile_environment = environment.copy()
        compile_environment["TMPDIR"] = str(temporary_root)

        app_probe = temporary_root / "app-contract-probe"
        widget_probe = temporary_root / "widget-contract-probe"
        compile_probe(
            swiftc,
            sdk,
            source_root,
            APP_CONTRACT_ROOT,
            harness,
            app_probe,
            "FonicAppWidgetContractProbe",
            module_cache,
            environment=compile_environment,
        )
        compile_probe(
            swiftc,
            sdk,
            source_root,
            WIDGET_CONTRACT_ROOT,
            harness,
            widget_probe,
            "FonicExtensionWidgetContractProbe",
            module_cache,
            environment=compile_environment,
        )

        app_payloads = temporary_root / "app-payloads"
        run_probe(
            app_probe,
            "encode-current",
            app_payloads,
            environment=isolated_probe_environment(
                environment,
                temporary_root / "preferences-app-encode",
                temporary_root,
            ),
        )
        run_probe(
            widget_probe,
            "decode-current",
            app_payloads,
            environment=isolated_probe_environment(
                environment,
                temporary_root / "preferences-widget-decode",
                temporary_root,
            ),
        )
        if verbose:
            print("[PASS] app_payloads_decode_with_widget_contract", flush=True)

        widget_payloads = temporary_root / "widget-payloads"
        run_probe(
            widget_probe,
            "encode-current",
            widget_payloads,
            environment=isolated_probe_environment(
                environment,
                temporary_root / "preferences-widget-encode",
                temporary_root,
            ),
        )
        run_probe(
            app_probe,
            "decode-current",
            widget_payloads,
            environment=isolated_probe_environment(
                environment,
                temporary_root / "preferences-app-decode",
                temporary_root,
            ),
        )
        if verbose:
            print("[PASS] widget_payloads_decode_with_app_contract", flush=True)

        for name, probe in (("app", app_probe), ("widget", widget_probe)):
            run_probe(
                probe,
                "decode-v1",
                fixture_root,
                environment=isolated_probe_environment(
                    environment,
                    temporary_root / f"preferences-{name}-legacy",
                    temporary_root,
                ),
            )
        if verbose:
            print("[PASS] frozen_v1_payloads_decode_with_both_contracts", flush=True)


def parse_arguments(arguments: Iterable[str]) -> argparse.Namespace:
    script_root = Path(__file__).resolve().parent
    repository_root = script_root.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source-root",
        type=Path,
        default=repository_root,
        help="Repository-shaped root containing both mirrored source directories.",
    )
    parser.add_argument(
        "--fixture-root",
        type=Path,
        default=script_root / "fixtures/widget-contracts/v1",
        help="Directory containing the frozen v1 App Group JSON payloads.",
    )
    parser.add_argument("--verbose", "-v", action="store_true")
    return parser.parse_args(list(arguments))


def main(arguments: Iterable[str] | None = None) -> int:
    options = parse_arguments(sys.argv[1:] if arguments is None else arguments)
    try:
        verify_contracts(
            options.source_root.resolve(),
            options.fixture_root.resolve(),
            verbose=options.verbose,
        )
    except VerificationFailure as error:
        print(f"[FAIL] {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
