import AppKit
import CoreGraphics
import ScreenCaptureKit

@MainActor
final class ScreenCaptureService {
    private var hasPresentedPermissionAlert = false

    func ensurePermission() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            hasPresentedPermissionAlert = false
            return true
        }

        if CGRequestScreenCaptureAccess() {
            hasPresentedPermissionAlert = false
            return true
        }

        presentPermissionAlertIfNeeded()
        return false
    }

    func capture(screen: NSScreen) async -> CGImage? {
        guard
            let displayID = displayID(for: screen),
            let display = await shareableDisplay(for: displayID)
        else {
            return nil
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = Int(screen.frame.width * screen.backingScaleFactor)
        configuration.height = Int(screen.frame.height * screen.backingScaleFactor)

        return await withCheckedContinuation { continuation in
            SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            ) { image, error in
                if error != nil {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard
            let screenNumber = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? NSNumber
        else {
            return nil
        }

        return CGDirectDisplayID(screenNumber.uint32Value)
    }

    private func shareableDisplay(for displayID: CGDirectDisplayID) async -> SCDisplay? {
        let shareableContent = try? await SCShareableContent.current

        return shareableContent?.displays.first { $0.displayID == displayID }
    }

    private func presentPermissionAlertIfNeeded() {
        guard !hasPresentedPermissionAlert else {
            return
        }

        hasPresentedPermissionAlert = true

        let alert = NSAlert()
        alert.messageText = "Screen Recording permission is required"
        alert.informativeText = """
        Allow Screen Recording for OverHyper in System Settings to use shader effects.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
