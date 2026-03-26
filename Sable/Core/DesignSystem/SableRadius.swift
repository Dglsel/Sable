import SwiftUI

/// Border radius tokens — DESIGN.md § Border Radius.
enum SableRadius {
    /// 4pt — Badges, tags, small chips
    static let sm: CGFloat = 4
    /// 6pt — Buttons, inputs, dropdowns
    static let md: CGFloat = 6
    /// 8pt — Cards, sidebar items, containers
    static let lg: CGFloat = 8
    /// 12pt — Large cards, mockup containers
    static let xl: CGFloat = 12
    /// 16pt — Message bubbles
    static let xxl: CGFloat = 16
    /// 18pt — Input bar, search fields
    static let pill: CGFloat = 18
    /// 9999pt — Circles, send button, status dots
    static let full: CGFloat = 9999
}
