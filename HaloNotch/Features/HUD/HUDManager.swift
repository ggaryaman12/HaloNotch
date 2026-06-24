import AppKit
import SwiftUI
import CoreAudio
import Observation

/// Replacement HUD for volume (and, on the roadmap, brightness). Owns a small
/// transient panel shown just below the notch. Volume changes are detected via a
/// Core Audio property listener on the default output device (best-effort: if the
/// listener can't be installed, `show(_:value:)` can still be called manually).
@Observable
final class HUDManager {
    enum Kind { case volume, brightness
        var symbol: String { self == .volume ? "speaker.wave.2.fill" : "sun.max.fill" }
    }

    private(set) var visible = false
    private(set) var kind: Kind = .volume
    private(set) var value: Double = 0.5
    /// Increments on every change so the bar can play a shutter-style pulse.
    private(set) var pulse: Int = 0

    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?
    private var enabled = false
    private var lastValue: Double = -1

    private var deviceID = AudioObjectID(0)
    private var listenerInstalled = false

    func start(enabled: Bool) {
        self.enabled = enabled
        guard enabled else { return }
        installVolumeListener()
    }

    /// Show the bar with a value (0...1), play a haptic + pulse, and auto-dismiss.
    func show(_ kind: Kind, value: Double) {
        guard enabled else { return }
        self.kind = kind
        self.value = min(max(value, 0), 1)
        ensurePanel()
        visible = true
        panel?.orderFrontRegardless()

        // Haptic tap on each step change (Force Touch trackpads), like a shutter.
        if abs(self.value - lastValue) > 0.001 {
            pulse &+= 1
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        }
        lastValue = self.value

        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.visible = false
            self?.panel?.orderOut(nil)
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: work)
    }

    // MARK: Left-edge bar panel

    private func ensurePanel() {
        if panel != nil { return }
        let screen = ScreenManager.currentMetrics().screen
        let f = screen.frame
        let size = CGSize(width: 40, height: 210)
        let origin = CGPoint(x: f.minX, y: f.midY - size.height / 2)   // flush to edge
        let p = NSPanel(contentRect: CGRect(origin: origin, size: size),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .statusBar
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        p.contentView = NSHostingView(rootView: VolumeBarView().environment(self))
        panel = p
    }

    // MARK: Core Audio volume detection

    private func installVolumeListener() {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID)
        guard status == noErr, deviceID != 0 else { return }

        var volAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        let listenerStatus = AudioObjectAddPropertyListenerBlock(
            deviceID, &volAddr, DispatchQueue.main) { [weak self] _, _ in
                self?.readVolumeAndShow()
            }
        listenerInstalled = (listenerStatus == noErr)
    }

    private func readVolumeAndShow() {
        var volAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        var vol = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &volAddr, 0, nil, &size, &vol)
        if status == noErr { show(.volume, value: Double(vol)) }
    }
}
