import AppKit
import Foundation
import HeadroomCore

enum AppQuitRequestResult {
    case requested
    case notFound
    case failed
}

@MainActor
final class AppQuitRequester {
    func canRequestQuit(identity: AppIdentity) -> Bool {
        matchingApplication(identity: identity) != nil
    }

    func requestQuit(identity: AppIdentity) -> AppQuitRequestResult {
        // Revalidate AFTER the confirmation dialog; names and PIDs alone are unsafe.
        guard let application = matchingApplication(identity: identity) else { return .notFound }
        return application.terminate() ? .requested : .failed
    }

    private func matchingApplication(identity: AppIdentity) -> NSRunningApplication? {
        guard let app = NSRunningApplication(processIdentifier: identity.pid), !app.isTerminated else { return nil }
        let current = TopAppSampler.footprint(for: app)?.identity
        let isSelf = app.processIdentifier == ProcessInfo.processInfo.processIdentifier ||
            app.bundleIdentifier == Bundle.main.bundleIdentifier
        let protectedIDs = ["com.apple.finder", "com.apple.dock", "com.apple.loginwindow", "com.apple.systemuiserver"]
        guard QuitEligibility.allows(selected: identity, current: current,
                                     isRegular: app.activationPolicy == .regular, isSelf: isSelf,
                                     isProtected: protectedIDs.contains(app.bundleIdentifier ?? "")) else { return nil }
        return app
    }
}
