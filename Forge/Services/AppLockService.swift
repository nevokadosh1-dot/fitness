import Foundation
import LocalAuthentication
import Observation

/// Optional Face ID / passcode lock. When enabled, the UI is covered until
/// the user authenticates; data itself already lives in the app sandbox.
@Observable
final class AppLockService {
    var isLocked = false
    var lastError: String?

    /// Whether the device supports any local authentication.
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func lockIfEnabled(settings: AppSettings) {
        if settings.appLockEnabled && Self.isAvailable {
            isLocked = true
        }
    }

    @MainActor
    func unlock() async {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock your fitness data"
            )
            if success {
                isLocked = false
                lastError = nil
            }
        } catch {
            lastError = error.localizedDescription
        }
    }
}
