import Foundation
import IOKit.ps
import Observation

/// Polls battery state via IOKit power sources. Low-frequency (30s) plus an initial
/// read; cheap enough for the idle notch. Reports percent + charging flag.
@Observable
final class BatteryMonitor {
    private(set) var percent: Int = 100
    private(set) var isCharging: Bool = false
    private(set) var hasBattery: Bool = true

    private var timer: Timer?

    func start() {
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.update()
        }
    }

    var isLow: Bool { hasBattery && percent <= 20 && !isCharging }

    private func update() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { hasBattery = false; return }

        guard let source = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]
        else { hasBattery = false; return }

        hasBattery = true
        if let cur = desc[kIOPSCurrentCapacityKey] as? Int,
           let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 {
            percent = Int((Double(cur) / Double(max) * 100).rounded())
        }
        if let charging = desc[kIOPSIsChargingKey] as? Bool {
            isCharging = charging
        } else if let state = desc[kIOPSPowerSourceStateKey] as? String {
            isCharging = (state == kIOPSACPowerValue)
        }
    }
}
