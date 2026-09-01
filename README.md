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

## Install on your iPhone

1. Make sure the iPhone runs iOS 26 or later.
2. In Xcode, open **Xcode > Settings > Accounts** and sign in with your Apple Account.
3. Connect the iPhone to the Mac with USB the first time, unlock it, and tap **Trust** if prompted.
4. Open **Window > Devices and Simulators**, select the iPhone, and optionally enable **Connect via network** for future wireless runs.
5. Open the Lutty target's **Signing & Capabilities** tab, leave automatic signing enabled, and select your team. A free Personal Team is sufficient.
6. If prompted, enable **Developer Mode** under **Settings > Privacy & Security** on the iPhone and complete its restart.
7. Select the iPhone as Xcode's run destination and press **Run**.

Apple documents [Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device) and [wireless device pairing](https://help.apple.com/xcode/mac/current/en.lproj/devbc48d1bad.html). Apps signed with a free Personal Team need to be rebuilt and reinstalled every seven days.

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
