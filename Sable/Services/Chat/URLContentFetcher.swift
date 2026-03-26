import Foundation
import os

/// Pre-fetches web page content from URLs found in user messages.
/// Inlines the extracted text into the prompt so any model can read it
/// without requiring server-side tools or API keys.
enum URLContentFetcher {

    private static let logger = Logger(subsystem: "ai.sable", category: "URLContentFetcher")

    // MARK: - URL Detection

    private static let urlPattern: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: #"https?://[^\s<>\"\]\)]+"#,
            options: .caseInsensitive
        )
    }()

    /// Extract all HTTP(S) URLs from a string.
    static func extractURLs(from text: String) -> [URL] {
        guard let regex = urlPattern else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let r = Range(match.range, in: text) else { return nil }
            return URL(string: String(text[r]))
        }
    }

    // MARK: - Fetch

    /// Fetch and extract readable text content from a URL.
    /// Returns nil if the fetch fails or the content isn't text-based.
    static func fetchContent(from url: URL, timeoutSeconds: TimeInterval = 10) async -> FetchedPage? {
        guard isPublicURL(url) else {
            logger.warning("Blocked fetch to non-public URL: \(url.absoluteString)")
            return nil
        }
        var request = URLRequest(url: url, timeoutInterval: timeoutSeconds)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        // Ask for HTML over JSON for GitHub etc.
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                         forHTTPHeaderField: "Accept")

        let config = URLSessionConfiguration.default
        config.connectionProxyDictionary = [:]
        let session = URLSession(configuration: config)

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                logger.warning("Fetch failed for \(url.absoluteString): HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return nil
            }

            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""

            // Only process text-based responses
            guard contentType.contains("text/") || contentType.contains("json") || contentType.contains("xml") else {
                logger.info("Skipping non-text content: \(contentType) for \(url.absoluteString)")
                return nil
            }

            guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
                return nil
            }

            let text = extractReadableText(from: html)
            guard !text.isEmpty else { return nil }

            // Truncate to avoid blowing up the context
            let maxChars = 8000
            let truncated = text.count > maxChars ? String(text.prefix(maxChars)) + "\n\n[Content truncated...]" : text
            let title = extractTitle(from: html)

            logger.info("Fetched \(url.host ?? ""): \(truncated.count) chars")

            return FetchedPage(url: url, title: title, content: truncated)
        } catch {
            logger.warning("Fetch error for \(url.absoluteString): \(error.localizedDescription)")
            return nil
        }
    }

    /// Fetch content for all URLs found in a message, in parallel.
    static func fetchAll(in text: String) async -> [FetchedPage] {
        let urls = extractURLs(from: text)
        guard !urls.isEmpty else { return [] }

        return await withTaskGroup(of: FetchedPage?.self, returning: [FetchedPage].self) { group in
            for url in urls.prefix(3) { // Max 3 URLs to avoid abuse
                group.addTask { await fetchContent(from: url) }
            }
            var results: [FetchedPage] = []
            for await result in group {
                if let page = result { results.append(page) }
            }
            return results
        }
    }

    // MARK: - SSRF Protection

    /// Reject URLs targeting localhost, private networks, or cloud metadata services.
    private static func isPublicURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }

        // Block localhost variants
        if host == "localhost" || host == "127.0.0.1" || host == "[::1]" || host == "0.0.0.0" {
            return false
        }

        // Block cloud metadata endpoints
        if host == "169.254.169.254" || host == "metadata.google.internal" {
            return false
        }

        // Block private IP ranges (RFC1918 + link-local)
        if let components = host.split(separator: ".").compactMap({ UInt8($0) }) as [UInt8]?,
           components.count == 4 {
            let a = components[0], b = components[1]
            if a == 10 { return false }                          // 10.0.0.0/8
            if a == 172 && (16...31).contains(b) { return false } // 172.16.0.0/12
            if a == 192 && b == 168 { return false }              // 192.168.0.0/16
            if a == 169 && b == 254 { return false }              // 169.254.0.0/16
        }

        return true
    }

    // MARK: - HTML → Text

    /// Strip HTML tags and extract readable text content.
    private static func extractReadableText(from html: String) -> String {
        var text = html

        // Remove script and style blocks
        let blockPatterns = [
            #"<script[^>]*>[\s\S]*?</script>"#,
            #"<style[^>]*>[\s\S]*?</style>"#,
            #"<nav[^>]*>[\s\S]*?</nav>"#,
            #"<footer[^>]*>[\s\S]*?</footer>"#,
            #"<header[^>]*>[\s\S]*?</header>"#,
            #"<!--[\s\S]*?-->"#
        ]
        for pattern in blockPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " ")
            }
        }

        // Convert common block elements to newlines
        let blockTags = ["</p>", "</div>", "</li>", "</h1>", "</h2>", "</h3>", "</h4>", "</h5>", "</h6>", "<br>", "<br/>", "<br />"]
        for tag in blockTags {
            text = text.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }

        // Strip remaining HTML tags
        if let tagRegex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            text = tagRegex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
        }

        // Decode common HTML entities
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&nbsp;", " "),
            ("&#x27;", "'"), ("&#x2F;", "/")
        ]
        for (entity, char) in entities {
            text = text.replacingOccurrences(of: entity, with: char)
        }

        // Collapse whitespace
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return lines.joined(separator: "\n")
    }

    /// Extract <title> from HTML.
    private static func extractTitle(from html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"<title[^>]*>([^<]+)</title>"#, options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Types

    struct FetchedPage: Sendable {
        let url: URL
        let title: String?
        let content: String

        /// Format as an inline context block for the prompt.
        var promptTag: String {
            let label = title ?? url.absoluteString
            return "<web_page url=\"\(url.absoluteString)\" title=\"\(label)\">\n\(content)\n</web_page>"
        }
    }
}
