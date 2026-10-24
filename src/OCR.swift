import Cocoa
import Vision

struct TextFragment {
    let text: String
    let bounds: CGRect
}

enum OCR {
    static func recognize(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["de-DE", "en-US"]
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        let fragments = (request.results ?? []).compactMap { observation -> TextFragment? in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            return TextFragment(text: text, bounds: observation.boundingBox)
        }
        return orderedText(fragments)
    }

    static func orderedText(_ fragments: [TextFragment]) -> String {
        let sorted = fragments.sorted {
            if $0.bounds.midY != $1.bounds.midY { return $0.bounds.midY > $1.bounds.midY }
            if $0.bounds.minX != $1.bounds.minX { return $0.bounds.minX < $1.bounds.minX }
            return $0.text < $1.text
        }
        var rows: [[TextFragment]] = []
        for fragment in sorted {
            if let row = rows.last, let anchor = row.first,
               anchor.bounds.midY - fragment.bounds.midY <= 0.012 {
                rows[rows.count - 1].append(fragment)
            } else {
                rows.append([fragment])
            }
        }
        return rows.map { row in
            row.sorted {
                if $0.bounds.minX != $1.bounds.minX { return $0.bounds.minX < $1.bounds.minX }
                return $0.text < $1.text
            }.map(\.text).joined(separator: " ")
        }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum Clipboard {
    enum CopyResult { case copied, changed, failed }

    static func copy(_ text: String, to pasteboard: NSPasteboard,
                     unchangedSince changeCount: Int) -> CopyResult {
        guard pasteboard.changeCount == changeCount else { return .changed }
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string) ? .copied : .failed
    }
}
