import Cocoa

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let defaultImage = NSImage(systemSymbolName: "text.viewfinder",
                                       accessibilityDescription: "Bild zu Text")
    private let defaultTooltip = "Klick: Bild aus Zwischenablage in Text umwandeln"
    private var busy = false
    private var feedbackTask: Task<Void, Never>?
    private var ocrTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = defaultImage
            button.target = self
            button.action = #selector(statusClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = defaultTooltip
        }
    }

    @objc private func statusClicked(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            runOCR()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        let quit = NSMenuItem(title: "Schließen", action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func runOCR() {
        guard !busy else { return }
        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        guard let image = imageFromPasteboard(pasteboard) else {
            if #available(macOS 15.4, *), pasteboard.accessBehavior == .alwaysDeny {
                flash(symbol: "xmark.circle.fill", tooltip: "Zugriff auf Zwischenablage nicht erlaubt")
            } else {
                flash(symbol: "xmark.circle.fill", tooltip: "Kein Bild in der Zwischenablage")
            }
            NSSound.beep()
            return
        }
        busy = true
        feedbackTask?.cancel()
        statusItem.button?.image = NSImage(systemSymbolName: "ellipsis.circle",
                                           accessibilityDescription: "Text wird erkannt")
        statusItem.button?.toolTip = "Text wird erkannt …"

        ocrTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Result { try OCR.recognize(image) }
            }.value
            guard let self, !Task.isCancelled else { return }
            self.busy = false
            self.ocrTask = nil
            switch result {
            case .failure(let error):
                self.flash(symbol: "xmark.circle.fill",
                           tooltip: "Texterkennung fehlgeschlagen: \(error.localizedDescription)")
                NSSound.beep()
            case .success(let text) where text.isEmpty:
                self.flash(symbol: "xmark.circle.fill", tooltip: "Kein Text erkannt")
                NSSound.beep()
            case .success(let text):
                switch Clipboard.copy(text, to: pasteboard, unchangedSince: changeCount) {
                case .copied:
                    self.flash(symbol: "checkmark.circle.fill", tooltip: "Text in Zwischenablage kopiert")
                case .changed:
                    self.flash(symbol: "xmark.circle.fill",
                               tooltip: "Zwischenablage geändert – Text nicht kopiert")
                case .failed:
                    self.flash(symbol: "xmark.circle.fill", tooltip: "Text konnte nicht kopiert werden")
                    NSSound.beep()
                }
            }
        }
    }

    private func imageFromPasteboard(_ pasteboard: NSPasteboard) -> CGImage? {
        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            if let data = pasteboard.data(forType: type),
               let image = NSImage(data: data),
               let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                return cgImage
            }
        }
        if let image = NSImage(pasteboard: pasteboard),
           let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cgImage
        }
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first, url.isFileURL,
           let image = NSImage(contentsOf: url),
           let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cgImage
        }
        return nil
    }

    private func flash(symbol: String, tooltip: String) {
        guard let button = statusItem.button else { return }
        feedbackTask?.cancel()
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        button.toolTip = tooltip
        feedbackTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(1300)) }
            catch { return }
            guard let self else { return }
            button.image = self.defaultImage
            button.toolTip = self.defaultTooltip
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        feedbackTask?.cancel()
        ocrTask?.cancel()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
