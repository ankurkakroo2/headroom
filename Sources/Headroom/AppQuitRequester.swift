import AppKit
import Foundation

enum AppQuitRequestResult {
    case requested(Int)
    case notFound
    case failed
}

final class AppQuitRequester {
    func canRequestQuit(appName: String) -> Bool {
        !matchingApplications(appName: appName).isEmpty
    }

    func requestQuit(appName: String) -> AppQuitRequestResult {
        let applications = matchingApplications(appName: appName)
        guard !applications.isEmpty else { return .notFound }

        let requestedCount = applications.reduce(0) { count, application in
            application.terminate() ? count + 1 : count
        }

        return requestedCount > 0 ? .requested(requestedCount) : .failed
    }

    private func matchingApplications(appName: String) -> [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { application in
            guard !application.isTerminated else { return false }
            guard application.bundleIdentifier != Bundle.main.bundleIdentifier else { return false }

            let bundleName = application.bundleURL?.deletingPathExtension().lastPathComponent
            return application.localizedName == appName || bundleName == appName
        }
    }
}
