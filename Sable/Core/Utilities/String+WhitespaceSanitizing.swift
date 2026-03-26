import Foundation

extension String {
    var removingWhitespaceAndNewlines: String {
        let filtered = unicodeScalars.filter { scalar in
            !CharacterSet.whitespacesAndNewlines.contains(scalar)
        }

        return String(String.UnicodeScalarView(filtered))
    }
}
