# Contributing to InnerCorners

Thank you for helping improve InnerCorners.

## Before opening an issue

- Check existing issues and the current [Beta release notes](https://github.com/mochiya-tako/InnerCorners/releases/tag/v0.12.0-beta.1).
- Do not deliberately reproduce a pointer-stuck condition if the normal report already contains enough information.
- Remove personal information from screenshots and diagnostics.
- Report security-sensitive behavior privately as described in [SECURITY.md](SECURITY.md).

## Bug reports

The most useful reports include:

- InnerCorners version and build.
- Mac model, macOS version, and pointing device.
- Number, name, resolution, scaling, and physical arrangement of displays.
- The exact display and corner involved.
- Expected and actual behavior.
- Whether Option passage and Control–Option–Command–Q remained available.

## Development

Use Xcode 27.2 or a compatible full Xcode installation with Swift 6 and the macOS SDK selected.

```sh
swift test
swift build -c release
Scripts/run_self_tests.sh
```

Cursor-control changes should include focused unit tests and real-device verification. Clearly distinguish automated checks from live multi-display testing.
