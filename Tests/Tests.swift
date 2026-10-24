import Cocoa

struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

@main
struct Tests {
    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw TestFailure(description: message) }
    }

    static func fragment(_ text: String, x: Double, y: Double) -> TextFragment {
        TextFragment(text: text, bounds: CGRect(x: x, y: y - 0.015, width: 0.1, height: 0.03))
    }

    @MainActor
    static func main() throws {
        let fragments = [fragment("Welt", x: 0.4, y: 0.8),
                         fragment("zweite Zeile", x: 0.1, y: 0.6),
                         fragment("Hallo", x: 0.1, y: 0.805)]
        try expect(OCR.orderedText(fragments) == "Hallo Welt\nzweite Zeile", "Zeilenreihenfolge")
        try expect(OCR.orderedText([]).isEmpty, "Leeres Ergebnis")
        try expect(OCR.orderedText([fragment("  ", x: 0, y: 0)]).isEmpty, "Leerzeichen")

        let a = fragment("A", x: 0.1, y: 0.500)
        let b = fragment("B", x: 0.2, y: 0.509)
        let c = fragment("C", x: 0.3, y: 0.518)
        for input in [[a,b,c], [a,c,b], [b,a,c], [b,c,a], [c,a,b], [c,b,a]] {
            try expect(OCR.orderedText(input) == "B C\nA", "Sortierung unabhängig von Eingabereihenfolge")
        }

        let pasteboard = NSPasteboard(name: .init("BildZuText.Tests.\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        try expect(pasteboard.setString("Bild", forType: .string), "Test-Zwischenablage")
        let initialCount = pasteboard.changeCount
        try expect(Clipboard.copy("Erkannt", to: pasteboard, unchangedSince: initialCount) == .copied,
                   "Unveränderte Zwischenablage")
        try expect(pasteboard.string(forType: .string) == "Erkannt", "Text kopiert")

        let beforeChange = pasteboard.changeCount
        pasteboard.clearContents()
        pasteboard.setString("Neu kopiert", forType: .string)
        try expect(Clipboard.copy("Altes OCR-Ergebnis", to: pasteboard,
                                  unchangedSince: beforeChange) == .changed, "Neue Kopie schützen")
        try expect(pasteboard.string(forType: .string) == "Neu kopiert", "Neue Kopie erhalten")

        let beforeClear = pasteboard.changeCount
        pasteboard.clearContents()
        try expect(Clipboard.copy("Altes OCR-Ergebnis", to: pasteboard,
                                  unchangedSince: beforeClear) == .changed, "Geleerte Zwischenablage schützen")

        if CommandLine.arguments.contains("--ocr") {
            let expected = ["Bild zu Text", "Prüfung unter macOS 27", "Clipboard 12345"]
            let text = try OCR.recognize(image(lines: expected))
            try expect(text == expected.joined(separator: "\n"), "OCR DE/EN: \(text)")
            let blank = try OCR.recognize(image(lines: []))
            try expect(blank.isEmpty, "Bild ohne Text")
            print("OCR OK")
        }
        print("Tests OK")
    }

    @MainActor
    static func image(lines: [String]) -> CGImage {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1400, pixelsHigh: 400,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 1400, height: 400).fill()
        for (index, line) in lines.enumerated() {
            (line as NSString).draw(at: NSPoint(x: 40, y: 290 - index * 100), withAttributes: [
                .font: NSFont.systemFont(ofSize: 54), .foregroundColor: NSColor.black
            ])
        }
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.cgImage!
    }
}
