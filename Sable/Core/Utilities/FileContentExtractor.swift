import Foundation
import PDFKit

/// Extracts human-readable text content from any file type.
/// Used to embed file contents into prompts so the model can read them.
enum FileContentExtractor {

    /// Attempt to extract text content from the file at the given URL.
    /// Returns extracted text, or nil only for image files (which are sent as base64 separately).
    static func extractText(from url: URL) -> String? {
        let ext = url.pathExtension.lowercased()

        // Images — handled as base64 attachments, not text
        if imageExtensions.contains(ext) {
            return nil
        }

        // Plain text / source code — direct UTF-8 read
        if textExtensions.contains(ext) {
            return try? String(contentsOf: url, encoding: .utf8)
        }

        // PDF — native PDFKit extraction
        if ext == "pdf" {
            return extractPDF(from: url)
        }

        // Office XML formats (docx, xlsx, pptx) — unzip and parse XML
        if ext == "docx" {
            return extractDocx(from: url)
        }
        if ext == "xlsx" {
            return extractXlsx(from: url)
        }
        if ext == "pptx" {
            return extractPptx(from: url)
        }

        // RTF
        if ext == "rtf" || ext == "rtfd" {
            return extractRTF(from: url)
        }

        // Last resort: try reading as UTF-8 text
        if let text = try? String(contentsOf: url, encoding: .utf8),
           text.count > 0,
           !text.contains("\0") {  // crude binary detection
            return text
        }

        // Truly unreadable binary — return a note instead of nil
        return "[Binary file: \(url.lastPathComponent) — content cannot be extracted]"
    }

    // MARK: - PDF

    private static func extractPDF(from url: URL) -> String? {
        guard let doc = PDFDocument(url: url) else { return nil }
        var pages: [String] = []
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i), let text = page.string, !text.isEmpty {
                pages.append("--- Page \(i + 1) ---\n\(text)")
            }
        }
        return pages.isEmpty ? "[PDF file with no extractable text]" : pages.joined(separator: "\n\n")
    }

    // MARK: - DOCX (Office Open XML)

    private static func extractDocx(from url: URL) -> String? {
        guard let xmlString = readZipEntry(zipURL: url, entryPath: "word/document.xml") else { return nil }
        return stripXMLTags(xmlString)
    }

    // MARK: - XLSX

    private static func extractXlsx(from url: URL) -> String? {
        // Read shared strings first
        let sharedStrings: [String]
        if let ssXML = readZipEntry(zipURL: url, entryPath: "xl/sharedStrings.xml") {
            sharedStrings = parseSharedStrings(ssXML)
        } else {
            sharedStrings = []
        }

        // Read sheet1 (most common case)
        guard let sheetXML = readZipEntry(zipURL: url, entryPath: "xl/worksheets/sheet1.xml") else { return nil }
        return parseSheet(sheetXML, sharedStrings: sharedStrings)
    }

    // MARK: - PPTX

    private static func extractPptx(from url: URL) -> String? {
        var allText: [String] = []
        // Try slides 1-50
        for i in 1...50 {
            guard let slideXML = readZipEntry(zipURL: url, entryPath: "ppt/slides/slide\(i).xml") else { break }
            let text = stripXMLTags(slideXML).trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                allText.append("--- Slide \(i) ---\n\(text)")
            }
        }
        return allText.isEmpty ? nil : allText.joined(separator: "\n\n")
    }

    // MARK: - RTF

    private static func extractRTF(from url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let attributed = NSAttributedString(rtf: data, documentAttributes: nil)
        return attributed?.string
    }

    // MARK: - ZIP Helpers

    /// Validate ZIP entry path contains only safe characters (no traversal or injection).
    private static let safeEntryPathPattern = try! NSRegularExpression(pattern: #"^[a-zA-Z0-9._/\[\] -]+$"#)

    /// Read a single entry from a ZIP archive using /usr/bin/unzip (available on all macOS).
    private static func readZipEntry(zipURL: URL, entryPath: String) -> String? {
        // Reject paths with traversal or unsafe characters
        let range = NSRange(entryPath.startIndex..., in: entryPath)
        guard !entryPath.contains(".."),
              safeEntryPathPattern.firstMatch(in: entryPath, range: range) != nil else {
            return nil
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", zipURL.path, entryPath]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        var data = Data()
        let readQueue = DispatchQueue(label: "sable.unzip.stdout")
        readQueue.async { data = pipe.fileHandleForReading.readDataToEndOfFile() }
        do {
            try process.run()
            process.waitUntilExit()
            readQueue.sync {}
            guard process.terminationStatus == 0 else { return nil }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    /// Naive XML tag stripper — good enough for extracting readable text from Office XML.
    private static func stripXMLTags(_ xml: String) -> String {
        // Replace paragraph/break tags with newlines first
        var result = xml
        result = result.replacingOccurrences(of: "<w:p[^>]*>", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "<a:p[^>]*>", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        // Strip all remaining tags
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Decode common XML entities
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&apos;", with: "'")
        // Clean up excess whitespace
        result = result.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        return result
    }

    // MARK: - XLSX Parsing

    private static func parseSharedStrings(_ xml: String) -> [String] {
        // Extract <t>...</t> values in order
        var strings: [String] = []
        let pattern = "<t[^>]*>([^<]*)</t>"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsString = xml as NSString
        let matches = regex.matches(in: xml, range: NSRange(location: 0, length: nsString.length))
        for match in matches {
            if match.numberOfRanges >= 2 {
                strings.append(nsString.substring(with: match.range(at: 1)))
            }
        }
        return strings
    }

    private static func parseSheet(_ xml: String, sharedStrings: [String]) -> String {
        // Extract cell values. Cells with t="s" reference shared strings by index.
        var rows: [Int: [(Int, String)]] = [:]
        let nsString = xml as NSString

        // Match each <c> cell element
        let cellPattern = "<c\\s+r=\"([A-Z]+)(\\d+)\"[^>]*(?:t=\"([^\"]*)\")?[^>]*/?>(?:<v>([^<]*)</v>)?"
        guard let cellRegex = try? NSRegularExpression(pattern: cellPattern) else {
            return stripXMLTags(xml)
        }

        let matches = cellRegex.matches(in: xml, range: NSRange(location: 0, length: nsString.length))
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let col = columnToIndex(nsString.substring(with: match.range(at: 1)))
            let row = Int(nsString.substring(with: match.range(at: 2))) ?? 0

            let cellType = match.range(at: 3).location != NSNotFound ? nsString.substring(with: match.range(at: 3)) : ""
            let rawValue = match.range(at: 4).location != NSNotFound ? nsString.substring(with: match.range(at: 4)) : ""

            let value: String
            if cellType == "s", let idx = Int(rawValue), idx < sharedStrings.count {
                value = sharedStrings[idx]
            } else {
                value = rawValue
            }

            if !value.isEmpty {
                rows[row, default: []].append((col, value))
            }
        }

        // Build CSV-like output
        let sortedRows = rows.keys.sorted()
        var lines: [String] = []
        for rowNum in sortedRows {
            guard let cells = rows[rowNum] else { continue }
            let sorted = cells.sorted { $0.0 < $1.0 }
            lines.append(sorted.map(\.1).joined(separator: "\t"))
        }
        return lines.isEmpty ? "[Spreadsheet with no extractable data]" : lines.joined(separator: "\n")
    }

    private static func columnToIndex(_ col: String) -> Int {
        var result = 0
        for char in col.uppercased() {
            result = result * 26 + Int(char.asciiValue ?? 65) - 64
        }
        return result
    }

    // MARK: - Extension Sets

    static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "bmp", "svg"
    ]

    static let textExtensions: Set<String> = [
        "txt", "md", "markdown", "rst",
        "swift", "kt", "py", "js", "ts", "jsx", "tsx",
        "go", "rs", "rb", "java", "c", "cpp", "h", "hpp",
        "cs", "php", "html", "htm", "css", "scss", "less",
        "json", "yaml", "yml", "toml", "xml", "csv",
        "sh", "bash", "zsh", "fish",
        "env", "gitignore", "dockerfile",
        "log", "sql", "graphql", "proto", "sol",
        "r", "m", "mm", "lua", "pl", "pm",
        "ini", "cfg", "conf", "properties",
        "makefile", "cmake", "gradle", "sbt",
        "tf", "hcl", "nix", "dhall"
    ]
}
