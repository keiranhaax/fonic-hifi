# SwiftUI and Presentation Instructions

These instructions extend the repository root guide for `Presentation/`.

## State and Composition

- Reuse existing `DesignTokens`, `ThemePalette`, navigation patterns, environment wiring, and glass modifiers. Do not create a parallel design system or imitate Liquid Glass with arbitrary material stacks.
- Follow the observation and state-ownership approach used by the surrounding feature. Do not mix paradigms within one view graph without a migration plan.
- Keep persistence, metadata extraction, artwork processing, audio work, and model generation outside SwiftUI `body`.
- Views render state and send user intent through established owners; they must not duplicate playback, queue, library, or persistence authority.
- Preserve existing navigation, presentation, focus, restoration, and error-state behavior while making local UI changes.

## Accessibility and Visual Behavior

- Custom controls require meaningful VoiceOver labels, values, hints or actions where needed, and a minimum 44-point target.
- Support Dynamic Type and avoid truncating essential controls or state at accessibility sizes.
- Communicate state without relying on color alone; respect Reduce Motion, Reduce Transparency, and Differentiate Without Color.
- Reuse semantic system behavior before adding custom accessibility workarounds.

## Verification

- Build the owning target and render or run the changed screen.
- Check relevant light/dark, accessibility-size, reduced-motion, reduced-transparency, empty, loading, error, and long-content states.
- Capture screenshots or video for material visual changes when the available harness supports it; report any state that remains manually unverified.
