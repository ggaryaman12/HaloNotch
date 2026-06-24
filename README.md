# HaloNotch

A native macOS app that turns the MacBook notch (or a floating pill on non-notch displays) into a dynamic, interactive island — media control center, audio visualizer, calendar glance, drag-and-drop file shelf, battery status, and a sleek HUD replacement — wrapped in tasteful 3D motion.

Independent reimplementation inspired by [Boring Notch](https://theboring.name/) / [TheBoredTeam/boring.notch](https://github.com/TheBoredTeam/boring.notch). Not a fork; no shared code.

> Status: **v0.1 vertical slice.** Builds, runs, and passes its test suite on macOS 26 / Xcode 26 (Apple Silicon). Some features are wired end-to-end; a few are scaffolded with graceful fallbacks (see *Feature status*).

## Features

- **Dynamic notch window** — borderless non-activating panel pinned under the physical notch; falls back to a centered pill on displays without one.
- **Three states** — idle (clock-light ambient), hover (3D lift + media glance), open (tabbed card). Pure, unit-tested state machine.
- **Media + visualizer** — Now Playing via the private MediaRemote framework (loaded with `dlopen`, no bundled binary); play/pause/next/prev; album art; bar visualizer that animates with playback and "breathes" when paused. Demo track fallback when no real source is available.
- **File shelf** — drag files onto the notch to stash; open / reveal in Finder / drag back out / AirDrop via `NSSharingService`.
- **Calendar** — next events + countdowns via EventKit (asks permission on first use; degrades gracefully if denied).
- **Battery** — live percent + charging/low color states via IOKit.
- **HUD replacement** — volume overlay near the notch, driven by a Core Audio volume listener.
- **Onboarding** — replayable 3D "portal" intro.
- **Settings (⌘,)** — module toggles, 3D-intensity, accent color, launch-at-login, onboarding replay, extension toggles.
- **Extension system** — `NotchExtension` protocol + registry with a built-in Clock example.

### Feature status

| Feature | State |
|---|---|
| Notch window / state machine / 3D | fully wired |
| Shelf (drop / open / reveal / AirDrop / drag-out) | fully wired |
| Battery (IOKit) | fully wired |
| Calendar (EventKit) | fully wired (needs permission) |
| Media transport + metadata | wired via MediaRemote; **Apple has locked this private API down on recent macOS — if the system returns nothing, a labelled demo track drives the UI** |
| HUD volume | wired via Core Audio; brightness detection is roadmap |
| Onboarding / Settings / Extensions | fully wired |

## Requirements

- macOS 14 Sonoma or later (developed on macOS 26).
- Apple Silicon or Intel.
- Xcode 26+ to build (project uses file-system-synchronized groups, objectVersion 77).

## Build & run

From Xcode:
1. `open HaloNotch.xcodeproj`
2. Select the **HaloNotch** scheme → Run (⌘R).

From the command line:
```bash
xcodebuild -project HaloNotch.xcodeproj -scheme HaloNotch -configuration Debug -destination 'platform=macOS' build
xcodebuild -project HaloNotch.xcodeproj -scheme HaloNotch -destination 'platform=macOS' test
```

The app is a menu-bar agent (`LSUIElement`) — no Dock icon. Look for the notch UI at the top of the screen and the menu-bar icon for Settings / Quit.

### Permissions

- **Calendar**: requested when you first open the Calendar tab. If denied, enable in System Settings ▸ Privacy & Security ▸ Calendars.
- No sandbox is used (the app needs the private MediaRemote framework and a Core Audio listener), so there are no entitlement prompts beyond Calendar.

### Unsigned / ad-hoc builds

The project signs ad-hoc (`CODE_SIGN_IDENTITY = "-"`). If macOS blocks a copied build, right-click the app ▸ Open, or System Settings ▸ Privacy & Security ▸ **Open Anyway**. For a stable Calendar permission grant, set your own Development Team in target settings.

## Signature 3D animations

- **Hover lift** — on cursor enter the notch tilts on X/Y with perspective and a soft shadow; `onContinuousHover` feeds a parallax offset scaled by the global 3D-intensity preference (`Theme/Motion.swift` → `lift(_:parallax:factor:)`).
- **Tab flip** — switching expanded tabs runs a `rotation3DEffect` flip with opacity fade (`Views/ExpandedView.swift` → `FlipModifier`).
- **Shelf chip tilt** — file chips tilt in 3D on hover.
- **Onboarding portal** — concentric gradient rings rotate on tilted 3D axes around a feature glyph (`Onboarding/OnboardingView.swift` → `Portal`).
- **HUD flip-in** — the volume overlay flips down from its top edge.

All motion suspends with state and respects a Low Power Mode check; set 3D intensity to *Off* in Settings to disable transforms entirely.

## Configure

Settings (⌘, or menu-bar ▸ Settings…): toggle modules, pick 3D intensity (off/subtle/balanced/dramatic), set accent hex, enable launch-at-login, replay onboarding, toggle extensions.

## Project layout

```
HaloNotch/
  App/            entry point + AppDelegate (panel + menu bar lifecycle)
  Core/           NotchWindow (NSPanel), ScreenManager (notch geometry)
  State/          AppEnvironment (DI), NotchState (machine), NotchViewModel
  Theme/          design tokens + motion tokens
  Views/          NotchRootView, Idle/Hover/Expanded
  Onboarding/     3D portal intro
  Settings/       Preferences (persisted) + SettingsView
  Extensions/     NotchExtension protocol + registry + Clock example
  Features/
    Media/ Visualizer/ Calendar/ Shelf/ Battery/ HUD/
HaloNotchTests/   state-machine, media, preferences tests
docs/             SPEC.md, ARCHITECTURE.md
```

## Roadmap

Reminders, webcam mirror, gesture control, weather, AirPods/Bluetooth battery, Live-Activity timers, notification mirroring, per-display config, brightness HUD detection, real-FFT audio into the visualizer (the engine already exposes `ingest(_:)`).

## Architecture & spec

See `docs/ARCHITECTURE.md` (modules, state machine, window strategy, perf rules) and `docs/SPEC.md` (features, user stories, UX states, non-functional requirements).
