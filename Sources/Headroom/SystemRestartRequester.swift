import Foundation

final class SystemRestartRequester {
    func requestRestart() -> String? {
        let source = "tell application \"System Events\" to restart"
        var error: NSDictionary?

        NSAppleScript(source: source)?.executeAndReturnError(&error)

        if let error {
            return error[NSAppleScript.errorMessage] as? String ?? "macOS declined the restart request."
        }
        return nil
    }
}
