//
//  String+HTML.swift
//  Enso
//

import Foundation
import AppKit

extension String {
    /// Extracts plain text from HTML content by stripping tags and decoding entities
    var strippingHTML: String {
        // First try using NSAttributedString for accurate HTML parsing
        if let data = self.data(using: .utf8),
           let attributedString = try? NSAttributedString(
               data: data,
               options: [
                   .documentType: NSAttributedString.DocumentType.html,
                   .characterEncoding: String.Encoding.utf8.rawValue
               ],
               documentAttributes: nil
           ) {
            return attributedString.string
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        }

        // Fallback: basic regex-based stripping
        var result = self

        // Remove script and style content entirely
        result = result.replacingOccurrences(
            of: "<script[^>]*>.*?</script>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        result = result.replacingOccurrences(
            of: "<style[^>]*>.*?</style>",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Replace block elements with newlines
        let blockTags = ["</p>", "</div>", "</tr>", "</li>", "<br>", "<br/>", "<br />"]
        for tag in blockTags {
            result = result.replacingOccurrences(of: tag, with: "\n", options: .caseInsensitive)
        }

        // Remove all remaining HTML tags
        result = result.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )

        // Decode common HTML entities
        let entities: [(String, String)] = [
            ("&nbsp;", " "),
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&apos;", "'"),
            ("&ndash;", "–"),
            ("&mdash;", "—"),
            ("&copy;", "©"),
            ("&reg;", "®"),
            ("&trade;", "™"),
            ("&euro;", "€"),
            ("&pound;", "£"),
            ("&yen;", "¥")
        ]

        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement, options: .caseInsensitive)
        }

        // Decode numeric entities
        result = result.replacingOccurrences(
            of: "&#(\\d+);",
            with: "",
            options: .regularExpression
        )

        // Clean up whitespace
        result = result
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
