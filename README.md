# ShoutPlex

A lightweight native iOS app for playing multiple Icecast/Shoutcast audio streams simultaneously, with per-stream panning and volume control.

## Requirements

- Xcode 15+
- iOS 16+ device or simulator
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Getting Started

```bash
xcodegen generate      # regenerate ShoutPlex.xcodeproj from project.yml
open ShoutPlex.xcodeproj
```

In Xcode, set your Development Team under **Signing & Capabilities**, select a device or simulator, and press **⌘R**.

> Audio streams work best on a physical device — background audio and live HTTP streams are unreliable in the simulator.

## Directory Structure

```
ShoutPlex-app/
├── project.yml                          # XcodeGen project spec (source of truth for project config)
├── ShoutPlex.xcodeproj                  # Generated — do not edit by hand
└── ShoutPlex/
    ├── App/
    │   ├── ShoutPlexApp.swift           # App entry point; configures AVAudioSession
    │   ├── Info.plist                   # Background audio mode, bundle metadata
    │   └── ShoutPlex.entitlements
    ├── Models/
    │   ├── AudioStream.swift            # Stream data model + PanMode enum (left/stereo/right)
    │   └── BroadcastifyCredentials.swift # Username/password model for Broadcastify auth
    ├── Services/
    │   └── AudioStreamPlayer.swift      # Core audio engine: one AVPlayer per stream,
    │                                    # panning via MTAudioProcessingTap, Now Playing info
    ├── ViewModels/
    │   └── StreamsViewModel.swift       # App state; play/pause/pan/volume; UserDefaults persistence
    ├── Views/
    │   ├── ContentView.swift            # Root view — stream list + toolbar
    │   ├── StreamRowView.swift          # Per-stream row: play button, pan picker, volume
    │   ├── AddStreamView.swift          # Sheet for adding a new stream URL
    │   ├── SettingsView.swift           # Broadcastify credential entry
    │   └── Theme.swift                  # Brand colors: spPink (#ed0b6f), spBlue (#337ab7)
    └── Assets.xcassets/                 # App icon, accent color
```

## Features

- **Multiple simultaneous streams** — each stream gets its own `AVPlayer`; `AVAudioSession.mixWithOthers` lets them play together
- **Per-stream panning** — Left / Stereo / Right, applied via `MTAudioProcessingTap` at the audio buffer level
- **Per-stream volume** — independent 0–100% volume slider per stream
- **Background playback** — continues playing when the app is backgrounded or the screen is locked
- **Lock screen / Control Center** — Now Playing card shows "ShoutPlex" with active stream count
- **Broadcastify auth** — add your credentials in Settings; they are injected automatically for any `broadcastify.com` stream URL

## Project Config

`project.yml` is the source of truth for build settings. After editing it, run `xcodegen generate` to regenerate the `.xcodeproj`. The generated project file is committed for convenience but can always be recreated.
