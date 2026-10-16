import SwiftUI

struct SettingsView: View {
    @AppStorage(DefaultsKey.openMode) private var openMode = OpenMode.window.rawValue
    @AppStorage(DefaultsKey.itermProfile) private var itermProfile = ""
    @AppStorage(DefaultsKey.defaultUser) private var defaultUser = ""
    @AppStorage(DefaultsKey.defaultTmuxPath) private var defaultTmuxPath = "/opt/homebrew/bin/tmux"
    @AppStorage(DefaultsKey.defaultControlMode) private var defaultControlMode = true
    @AppStorage(DefaultsKey.showMenuBarExtra) private var showMenuBar = true

    var body: some View {
        Form {
            Section("iTerm") {
                Picker("Open in", selection: $openMode) {
                    ForEach(OpenMode.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                TextField("Profile", text: $itermProfile, prompt: Text("Default profile"))
                if !ITermLauncher.isInstalled {
                    Label("iTerm is not installed", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            Section("Defaults for New Sessions") {
                TextField("User", text: $defaultUser, prompt: Text("user"))
                TextField("tmux path", text: $defaultTmuxPath, prompt: Text("/opt/homebrew/bin/tmux"))
                Toggle("iTerm integration (-CC)", isOn: $defaultControlMode)
            }

            Section("General") {
                Toggle("Show in menu bar", isOn: $showMenuBar)
                LabeledContent("Configuration") {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([SessionStore.fileURL])
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
