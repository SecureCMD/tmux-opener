import SwiftUI

@main
struct TmuxOpenerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = SessionStore()
    @AppStorage(DefaultsKey.showMenuBarExtra) private var showMenuBar = true

    var body: some Scene {
        Window("Tmux Opener", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 480, minHeight: 360)
        }
        .defaultSize(width: 780, height: 540)
        .commands { AppCommands(store: store) }

        Settings {
            SettingsView()
        }

        MenuBarExtra("Tmux Opener", systemImage: "terminal.fill", isInserted: $showMenuBar) {
            MenuBarContent()
                .environmentObject(store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !UserDefaults.standard.bool(forKey: DefaultsKey.showMenuBarExtra)
            && UserDefaults.standard.object(forKey: DefaultsKey.showMenuBarExtra) != nil
    }
}

struct AppCommands: Commands {
    @ObservedObject var store: SessionStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Session…") { store.newSession() }
                .keyboardShortcut("n", modifiers: .command)
        }
        CommandGroup(after: .importExport) {
            Button("Import Sessions…") { store.importSessions() }
            Button("Export Sessions…") { store.exportSessions() }
            Divider()
            Button("Show Configuration in Finder") { store.revealConfig() }
        }
        CommandMenu("Sessions") {
            ForEach(Array(store.sessions.prefix(9).enumerated()), id: \.element.id) { index, session in
                Button(session.displayName) { store.launch(session) }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
            }
            if store.sessions.isEmpty {
                Text("No Sessions")
            }
        }
    }
}

struct MenuBarContent: View {
    @EnvironmentObject var store: SessionStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ForEach(store.sessions) { session in
            Button {
                store.launch(session)
            } label: {
                Label(session.displayName, systemImage: session.symbol)
            }
        }
        if store.sessions.isEmpty {
            Text("No Sessions")
        }
        Divider()
        Button("Open Tmux Opener…") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("New Session…") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
            store.newSession()
        }
        Divider()
        Button("Quit Tmux Opener") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
