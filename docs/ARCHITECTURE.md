# HaloNotch — Architecture

## Stack
- **Swift 6**, **SwiftUI** for views, **AppKit** for the window layer (`NSPanel`), screen geometry, drag/drop, sharing.
- **Core Animation / SwiftUI 3D transforms** (`rotation3DEffect`, `matchedGeometryEffect`, parallax) for motion. No SceneKit/Metal needed for the target effects (kept GPU-light); Metal is an option later for the visualizer.
- **EventKit** (calendar), **IOKit** (battery), **MediaRemote** private framework via `dlopen` (now playing).
- Target: **macOS 14+** (developed on macOS 26 / Xcode 26). Apple Silicon + Intel.
- Pattern: **MVVM** + injectable services. Views observe `@Observable` view models; view models depend on service protocols.

## Module map

```
App            HaloNotchApp (entry), AppDelegate (activation policy, panel lifecycle, menu bar)
Core           NotchWindow (NSPanel subclass), ScreenManager (notch geometry/detection), NotchMetrics
State          NotchViewModel (state machine), NotchState (enum), AppEnvironment (DI container)
Theme          Theme (tokens: color/typography/spacing), Motion (durations/easings/3D intensity)
Views          NotchRootView, NotchContainer (sizing host), IdleView, HoverView, ExpandedView, TabBar
Onboarding     OnboardingView, PortalScene (3D intro)
Settings       SettingsView, Preferences (@Observable, UserDefaults-backed)
Extensions     NotchExtension (protocol), ExtensionRegistry
Features/
  Media        MediaController (protocol), MediaRemoteController (impl), NowPlaying (model), MediaView
  Visualizer   VisualizerEngine (@Observable level source), VisualizerView (bars)
  Calendar     CalendarService (EventKit), CalendarView
  Shelf        ShelfModel (@Observable), ShelfItem, ShelfView (drop target + chips)
  Battery      BatteryMonitor (IOKit), BatteryView
  HUD          HUDManager (observes system vol/brightness), HUDOverlayView
```

## Communication
- **AppEnvironment** is a single `@Observable` DI container created in `AppDelegate`, injected into the SwiftUI tree via `.environment`. Holds: `Preferences`, `MediaController`, `VisualizerEngine`, `BatteryMonitor`, `ShelfModel`, `CalendarService`, `HUDManager`, `ExtensionRegistry`.
- **NotchViewModel** owns the UI state machine and mouse tracking; views read `vm.state`.
- Services are protocol-typed so they can be swapped for previews/tests (e.g. `MockMediaController`).
- Notifications: `HUDManager` posts state changes the panel reacts to; system events come via `NSEvent` global monitors and IOKit/distributed notifications.

## State machine

```
              cursor enter            click / tap
   closed  ───────────────▶ hovered ───────────────▶ open
     ▲                         │                        │
     │      cursor exit        │   cursor exit (delay)  │  click outside / Esc
     └─────────────────────────┴────────────────────────┘

   any ──(volume/brightness key)──▶ hudInterrupt ──(timeout)──▶ previous
```
Implemented as an enum `NotchState { closed, hovered, open, hud(HUDKind) }` with guarded transitions in `NotchViewModel`. Pure transition logic is unit-tested (no UI needed).

## Window strategy
- A single borderless `NSPanel`: `.nonactivatingPanel`, `level = .statusBar+`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`, ignores mouse when closed except a hover tracking strip.
- `ScreenManager` finds the screen with the menu bar, reads `safeAreaInsets.top` / `auxiliaryTopLeftArea` to locate the real notch; if absent, synthesizes a centered pill rect.
- Panel frame = notch rect, grown downward as state opens. SwiftUI content sized by `NotchContainer` via the current state's target size with spring animation.

## Performance rules
- Visualizer `CADisplayLink`-style ticking only while `state != .closed` AND media playing AND display awake.
- Clock timer at 1Hz; battery polled at 30s + on power-source-change notification.
- Parallax mouse monitor installed only while hovered/open.
- Low Power Mode → motion intensity clamped, frame rate halved.

## Resilience
- MediaRemote symbol resolution wrapped in optionals; failure disables the media module and logs once.
- EventKit / sharing failures surface as inline empty states, never crashes.
- All `@Observable` services initialise to safe empty defaults.

## Testing
- `NotchStateMachineTests` — transition table.
- `MediaControllerTests` — uses `MockMediaController`.
- `PreferencesTests` — persistence round-trip.
