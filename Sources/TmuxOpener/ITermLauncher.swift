import AppKit

enum LaunchError: LocalizedError {
    case itermNotInstalled
    case notAuthorized
    case script(String)

    var errorDescription: String? {
        switch self {
        case .itermNotInstalled:
            return String(localized: "iTerm couldn’t be found. Install it from iterm2.com.")
        case .notAuthorized:
            return String(localized: "Tmux Opener isn’t allowed to control iTerm. Enable it in System Settings → Privacy & Security → Automation.")
        case .script(let msg):
            return msg
        }
    }
}

enum ITermLauncher {
    static let bundleID = "com.googlecode.iterm2"

    static var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    static func run(command: String, mode: OpenMode, profile: String) throws {
        guard isInstalled else { throw LaunchError.itermNotInstalled }

        let wasRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
        let profileClause = profile.trimmed.isEmpty
            ? "default profile"
            : "profile \"\(escape(profile.trimmed))\""

        // If iTerm wasn't running, reuse the window it opens on launch
        // instead of leaving an extra empty one behind.
        let script = """
        tell application id "\(bundleID)"
            activate
            set reuseWindow to false
            if \(wasRunning ? "false" : "true") then
                repeat 15 times
                    if (count of windows) > 0 then exit repeat
                    delay 0.1
                end repeat
                if (count of windows) > 0 then set reuseWindow to true
            end if
            if reuseWindow then
                set targetSession to current session of current window
            else if "\(mode.rawValue)" is "tab" and (count of windows) > 0 then
                tell current window
                    set newTab to (create tab with \(profileClause))
                end tell
                set targetSession to current session of newTab
            else
                set newWindow to (create window with \(profileClause))
                set targetSession to current session of newWindow
            end if
            tell targetSession to write text "\(escape(command))"
        end tell
        """

        var errorInfo: NSDictionary?
        guard let apple = NSAppleScript(source: script) else {
            throw LaunchError.script(String(localized: "Couldn’t prepare the AppleScript."))
        }
        apple.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let code = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
            if code == -1743 { throw LaunchError.notAuthorized }
            let msg = errorInfo[NSAppleScript.errorMessage] as? String ?? String(localized: "Unknown error (\(code)).")
            throw LaunchError.script(msg)
        }
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
