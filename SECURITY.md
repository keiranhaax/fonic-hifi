# Security Policy

Fonic HiFi is a privacy-first, fully offline iOS music player. It makes no network requests, uses no cloud services or analytics, and stores all data locally on device. The primary security surface is local: audio file and metadata parsing, security-scoped bookmark handling, the SwiftData store, and the App Group contract shared with the widget.

## Supported Versions

The project is currently an unreleased technical preview.

| Version | Supported |
| --- | --- |
| Latest `main` | ✅ |
| Tagged pre-releases (once published) | Latest tag only |
| Anything older | ❌ |

Until a stable 1.0 release exists, security fixes land on `main` only. After tagged releases begin, only the most recent release receives fixes.

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues, discussions, or pull requests.**

Private vulnerability reporting is not currently enabled for this repository. Open a
minimal GitHub issue requesting a private reporting channel, without including exploit
details, sensitive data, or a proof of concept. A maintainer will arrange a private
follow-up channel.

In that private follow-up, include a description of the issue, reproduction steps or a
proof-of-concept file, the affected component (e.g., import pipeline, metadata parsing,
bookmark handling), and the impact you believe it has.

If a sample media file triggers the issue, describe how to construct it rather than attaching copyrighted material.

### What to Expect

- Acknowledgement of your report within 7 days.
- An assessment and, when confirmed, a fix on `main` with credit in the release notes (unless you prefer to remain anonymous).
- Coordinated disclosure: please allow a fix to land before publishing details.

## Scope

In scope:

- Crashes or memory corruption triggered by malformed audio files or metadata
- Path traversal or sandbox escape via imports, bookmarks, or file access
- Data exposure through logs, exports, or the App Group shared with the widget

Out of scope:

- Issues requiring a jailbroken device or physical access to an unlocked device
- Vulnerabilities in Apple frameworks or in AudioKit itself (report upstream; we will track the pinned version)
