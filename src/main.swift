import Cocoa
import Vision

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var defaultImage: NSImage!
    var busy = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        defaultImage = NSImage(systemSymbolName: "text.viewfinder",
                               accessibilityDescription: "Bild zu Text")
        if let button = statusItem.button {
            button.image = defaultImage
            button.target = self
            button.action = #selector(statusClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Klick: Bild aus Zwischenablage in Text umwandeln"
        }
    }

    @objc func statusClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { runOCR(); return }
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            runOCR()
        }
    }

    func showMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Schließen",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc func runOCR() {
        if busy { return }
        guard let cgImage = imageFromPasteboard() else {
            flash(symbol: "xmark.circle.fill", tooltip: "Kein Bild in der Zwischenablage")
            NSSound.beep()
            return
        }
        busy = true
        setIcon(symbol: "ellipsis.circle")

        let request = VNRecognizeTextRequest { [weak self] req, err in
            guard let self = self else { return }
            var text = ""
            if err == nil, let obs = req.results as? [VNRecognizedTextObservation] {
                let sorted = obs.sorted { a, b in
                    if abs(a.boundingBox.midY - b.boundingBox.midY) > 0.012 {
                        return a.boundingBox.midY > b.boundingBox.midY
                    }
                    return a.boundingBox.minX < b.boundingBox.minX
                }
                text = sorted.compactMap { $0.topCandidates(1).first?.string }
                             .joined(separator: "\n")
            }
            DispatchQueue.main.async {
                self.busy = false
                if text.isEmpty {
                    self.flash(symbol: "xmark.circle.fill", tooltip: "Kein Text erkannt")
                    NSSound.beep()
                } else {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(text, forType: .string)
                    self.flash(symbol: "checkmark.circle.fill",
                               tooltip: "Text in Zwischenablage kopiert")
                }
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["de-DE", "en-US"]

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    func imageFromPasteboard() -> CGImage? {
        let pb = NSPasteboard.general
        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            if let data = pb.data(forType: type),
               let img = NSImage(data: data),
               let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                return cg
            }
        }
        if let img = NSImage(pasteboard: pb),
           let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cg
        }
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let url = urls.first,
           let img = NSImage(contentsOf: url),
           let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cg
        }
        return nil
    }

    func setIcon(symbol: String) {
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
    }

    func flash(symbol: String, tooltip: String) {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        button.toolTip = tooltip
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { [weak self] in
            guard let self = self else { return }
            button.image = self.defaultImage
            button.toolTip = "Klick: Bild aus Zwischenablage in Text umwandeln"
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
