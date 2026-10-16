import AppKit

/// Stages the README screenshots. Not used in normal runs.
///
///     open "build/Tmux Opener.app" --args -screenshotDir /tmp/shots \
///         -screenshotAppearance dark -configDirectory docs/demo
///
/// Captures the main window, the session editor and the settings window,
/// then quits. An app may capture its own windows without Screen Recording access.
@MainActor
enum ScreenshotRunner {
    private static var started = false

    static func runIfRequested(store: SessionStore, openSettings: @escaping () -> Void) {
        let defaults = UserDefaults.standard
        guard !started, let dir = defaults.string(forKey: "screenshotDir") else { return }
        started = true

        let appearance = defaults.string(forKey: "screenshotAppearance") ?? "light"
        NSApp.appearance = NSAppearance(named: appearance == "dark" ? .darkAqua : .aqua)
        let out = URL(fileURLWithPath: (dir as NSString).expandingTildeInPath, isDirectory: true)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            let main = NSApp.windows.first { $0.isVisible && $0.title == "Tmux Opener" }
            capture(main, to: out.appendingPathComponent("main-\(appearance).png"))

            if let first = store.sessions.first {
                store.edit(first)
                try? await Task.sleep(for: .seconds(1.2))
                main?.attachedSheet?.makeFirstResponder(nil)
                try? await Task.sleep(for: .seconds(0.3))
                capture(main?.attachedSheet,to: out.appendingPathComponent("editor-\(appearance).png"))
                store.editing = nil
                try? await Task.sleep(for: .seconds(0.8))
            }

            openSettings()
            try? await Task.sleep(for: .seconds(1.2))
            let settings = NSApp.windows.first { $0.isVisible && $0 !== main && !$0.isSheet && $0.level == .normal }
            capture(settings, to: out.appendingPathComponent("settings-\(appearance).png"))

            NSApp.terminate(nil)
        }
    }

    private typealias CreateImage = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?

    private static func capture(_ window: NSWindow?, to url: URL) {
        guard let window else {
            NSLog("TmuxOpener: no window to capture for \(url.lastPathComponent)")
            return
        }
        var image: CGImage?
        // On a non-Retina display, render the view tree at 2x instead so the
        // README images stay sharp (no window shadow in that case).
        if window.backingScaleFactor < 2, let view = window.contentView?.superview {
            let size = view.bounds.size
            if let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
                                          bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                          colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) {
                rep.size = size
                view.cacheDisplay(in: view.bounds, to: rep)
                image = rep.cgImage
            }
        }
        // CGWindowListCreateImage is hidden from Swift in recent SDKs but still works
        // for the app's own windows, and keeps the real shadow and vibrancy.
        if image == nil, let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage") {
            let create = unsafeBitCast(sym, to: CreateImage.self)
            let includingWindow: UInt32 = 1 << 3
            let bestResolution: UInt32 = 1 << 3
            image = create(.null, includingWindow, UInt32(window.windowNumber), bestResolution)?.takeRetainedValue()
        }
        if image == nil, let view = window.contentView?.superview {
            let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)
            if let rep {
                view.cacheDisplay(in: view.bounds, to: rep)
                image = rep.cgImage
            }
        }
        guard let image,
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url)
    }
}
