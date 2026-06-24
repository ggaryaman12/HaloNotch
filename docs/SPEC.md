# HaloNotch — Functional Spec

A native macOS app that turns the MacBook notch (or a floating pill on non-notch displays) into a dynamic, interactive island: media control center, audio visualizer, calendar glance, drag-and-drop file shelf, battery status, and sleek HUD replacements — wrapped in tasteful 3D motion.

Inspired by [Boring Notch](https://theboring.name/) / [TheBoredTeam/boring.notch](https://github.com/TheBoredTeam/boring.notch). This is an independent reimplementation, not a fork.

## Core value prop

Reclaim the dead pixels around the notch and make them the most useful 200×40 points on the machine. Glanceable when idle, powerful on hover, never in the way.

## Feature list

### Implemented in this codebase (v0.1 vertical slice)
- **Notch window**: borderless non-activating `NSPanel` pinned under the physical notch; falls back to a centered floating pill on displays without a notch.
- **State machine**: `closed → hovered → open` with a HUD interrupt state, driven by mouse tracking.
- **Idle view**: ambient — live clock, battery glyph, tiny now-playing dot/equalizer when audio is active.
- **Hover view**: subtle 3D lift (perspective + parallax), quick-glance media + battery.
- **Expanded view**: tabbed card — Media, Calendar, Shelf — with album art, transport controls, visualizer.
- **Media controller**: real Now Playing via the private `MediaRemote` framework (loaded with `dlopen`, no bundled binary), play/pause/next/prev, scrubbing, album art + dominant-color theming. Graceful no-media empty state.
- **Visualizer**: GPU-light bar/equalizer that reacts to playback state (animated while playing, "breathing" idle when paused). Architected to accept real FFT samples later.
- **Battery**: live percentage, charging/low states, color-coded glyph.
- **File shelf**: drag files onto the notch to stash; per-item open / reveal-in-Finder / drag-back-out / AirDrop via `NSSharingService`.
- **HUD overlay**: replacement volume & brightness HUD that animates in near the notch on system change.
- **Onboarding**: replayable first-run 3D "portal" intro using layered `rotation3DEffect` / parallax / `matchedGeometryEffect`.
- **Settings**: module toggles, 3D-intensity slider, theme/accent, launch-at-login, re-run onboarding.
- **Extension system**: `NotchExtension` protocol + registry so new notch panels can be added without touching core.

### Roadmap (designed-for, not wired)
Reminders, webcam mirror, gesture control, weather, Bluetooth/AirPods battery, Live-Activity style timers, notification mirroring, multi-display per-screen config, iCloud sync of shelf.

## User stories (power user, MacBook)

- As a user playing Spotify/Apple Music, I glance at the notch and see a tiny equalizer; I hover and get scrub + skip without leaving my current app.
- I'm dragging a screenshot to share — I flick it up to the notch, it parks in the shelf, later I drag it into Slack or AirDrop it.
- I press a media key — instead of the stock macOS HUD, a matching overlay slides out beside the notch.
- Before a call, I open the notch, see my next meeting and how many minutes until it.
- On battery, the notch glyph turns amber under 20%; charging shows a bolt.
- I disable the Shelf module and crank 3D intensity to "subtle" in Settings; my prefs persist.

## UX states

| State | Trigger | Shows | Motion |
|-------|---------|-------|--------|
| Idle / closed | no interaction | clock, battery, mini-EQ when audio | none (static, ~0% CPU) |
| Hovered | cursor enters notch rect | glance media + battery, subtle lift | 3D lift in (perspective, ~0.25s spring) |
| Open / expanded | click | tabbed card (Media/Calendar/Shelf) | height+opacity spring, content cross-3D |
| Media playing | now-playing present | album art, transport, visualizer | art color bleeds into card; EQ animates |
| No media | nothing playing | "Nothing playing" empty state | EQ breathes slowly |
| Calendar | tab select | next events + countdown | tab slides with depth |
| Shelf active | files dropped / tab | file chips | chips tilt on hover; drop = bounce |
| HUD overlay | volume/brightness change | slider near notch | flip/slide in, auto-dismiss ~1.5s |
| Drag-over | file dragged near notch | "Drop to stash" affordance | notch widens, glow |

## Non-functional requirements

- **Idle cost**: closed state must be near-zero CPU — no timers running faster than the clock (1s), visualizer paused when closed.
- **Responsiveness**: hover→lift < 16ms to first frame; open spring 60fps on M-series.
- **Permissions**: Calendar (EventKit) and media are optional; every feature degrades gracefully if denied. No crash on denial.
- **Memory**: target < 80MB resident idle.
- **Battery impact**: visualizer and parallax suspend when notch closed or display asleep; respects Low Power Mode (drops animation rate).
- **Resilience**: private MediaRemote symbols are resolved defensively; missing symbols → media module disables itself, rest of app runs.
- **Multi-display**: renders on the screen with the menu bar; reflows to pill on non-notch screens.
