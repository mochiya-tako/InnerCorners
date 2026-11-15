# InnerCorners development summary

This document summarizes the development record through v0.11.0 RC7. The complete, chronological test record is retained in [Japanese](DEVELOPMENT_HISTORY_JA.md).

## Prototype phase

- Established independent per-display corner zones, dwell timing, and reactivation latches.
- Added live geometry diagnostics and previews for multi-display layouts.
- Replaced unreliable synthetic Mission Control shortcuts with system-facing action paths.

## Directional barrier phase

- Added short, directional barriers at physical display junctions.
- Hardened collision detection for high-speed movement, exact outer-edge coordinates, shared multi-display points, and ambiguous entry direction.
- Separated barrier length from the shorter action re-arm distance.
- Defined the product concept as a persistent inner-corner wall whenever barriers are enabled.

## Safety phase

- Added Option-key emergency passage, normal Command–Q termination, and an independent Control–Option–Command–Q emergency quit path.
- Added sleep and display-change safety gates: barriers restart only after five seconds and confirmation that the pointer is in a safe position.
- Prevented transitional or empty display configurations from re-enabling stale barriers.
- Kept barriers active during dragging while suppressing assigned actions.
- Added duplicate-process prevention and made the app visible in the Dock and Command–Tab.

## Public-API and usability phase

- Removed the private CoreDock action path and retained public system-facing alternatives.
- Added Japanese and English UI selection.
- Added Quick Note, Notification Center, Lock Screen, Start Screen Saver, and Put Display to Sleep.
- Added Shift, Control, and Command requirements for system hot-corner assignments. Option remains reserved for emergency passage.
- Added privacy-reduced action diagnostics that omit display names, application names, window titles, and detailed failure reasons.

## RC1–RC7

- RC1 fixed the beta 2 candidate after live diagnostics verification.
- RC2 integrated common safety gates for custom zones, Option bypass, and sleep/wake behavior.
- RC3 corrected stale custom-zone status in the UI.
- RC4 preserved zone latches across identical display notifications and separated barrier-covered corners from custom-zone execution.
- RC5 delegated native outer corners back to macOS to prevent double toggles.
- RC6 exposed the additional actions directly in each display/corner picker.
- RC7 hardened mirrored-display handling against duplicate display-number keys and made source archives compatible with standard command-line ZIP extraction.

## Live configurations covered

Recorded testing includes two- and three-display horizontal, vertical, L-shaped, convex, T-shaped, disconnect/reconnect, sleep/wake, and mirrored configurations. The current principal test system is Apple Silicon with macOS 27.0.1.

These tests are evidence for the recorded configurations only. They do not establish universal compatibility with every supported macOS version, Mac, display, input device, or keyboard layout.
