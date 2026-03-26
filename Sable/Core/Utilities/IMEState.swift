import AppKit

/// Detects whether an IME (Input Method Editor) is currently composing text.
/// Used to prevent Enter key from sending a message while the user is confirming
/// a candidate in Chinese, Japanese, Korean, or other IME-based input methods.
enum IMEState {

    /// Returns `true` if the first responder has active marked text (IME composing).
    static var isComposing: Bool {
        guard let firstResponder = NSApp.keyWindow?.firstResponder as? NSTextView else {
            return false
        }
        return firstResponder.hasMarkedText()
    }
}
