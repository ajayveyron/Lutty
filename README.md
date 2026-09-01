# Lutty

Lutty is a small, local-first iPhone photo editor for importing `.cube` LUTs, applying them to still photos, making a few essential color adjustments, and saving a new copy.

## Features

- Import and validate standard 3D `.cube` LUTs from Files
- Start with four original warm presets: Soft Warm, Golden Hour, Rose Fade, and Story Glow
- Rename, reuse, and delete LUTs stored locally on the device
- Edit JPEG, HEIC, and PNG still photos from the Photos picker
- Tune LUT strength, exposure, contrast, saturation, and temperature
- Press and hold the preview to compare against the original
- Export full-resolution HEIC or PNG output to Photos and the share sheet
- Native SwiftUI interface using iOS Liquid Glass

Lutty does not use accounts, analytics, networking, or cloud storage. Photos and LUTs remain on the device.

## Requirements

- Xcode 26 or later
- iOS 26 or later
- An Apple development team selected in Xcode to install on a physical iPhone

## Run locally

1. Open `Lutty.xcodeproj` in Xcode.
2. Select the **Lutty** target and choose your development team under Signing & Capabilities.
3. Connect your iPhone, select it as the run destination, and press Run.

The checked-in Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen). Re-run `xcodegen generate` after changing the project specification.

The bundled presets are generated from the original formulas in `Scripts/generate_bundled_luts.swift`. Run `swift Scripts/generate_bundled_luts.swift` to regenerate their `.cube` files.

## Tests

The test suite covers LUT parsing and validation, local library persistence, Core Image rendering, orientation, PNG alpha, HEIC export, and basic UI navigation.

```sh
xcodebuild -project Lutty.xcodeproj \
  -scheme Lutty \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

## License

This is a personal project. No license is granted for redistribution or commercial use.
