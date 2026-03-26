import SwiftUI

/// Motion tokens — DESIGN.md § Motion.
enum SableAnimation {

    // MARK: - Durations

    /// 80ms — Press feedback, button compression
    static let micro: Double = 0.08
    /// 120ms — Hover states, toggles, color shifts
    static let fast: Double = 0.12
    /// 200ms — Expand/collapse, modals, focus ring
    static let normal: Double = 0.20
    /// 350ms — Page transitions, large state changes
    static let slow: Double = 0.35
    /// 420ms — Message appearance, view transitions
    static let entrance: Double = 0.42

    // MARK: - Spring Presets

    /// UI feedback, button press — response 0.25, damping 0.92
    static let springInteractive = Animation.spring(response: 0.25, dampingFraction: 0.92)
    /// Entrance animations — response 0.38, damping 0.78
    static let springBouncy = Animation.spring(response: 0.38, dampingFraction: 0.78)
    /// Large element entrance — response 0.55, damping 0.75
    static let springGentle = Animation.spring(response: 0.55, dampingFraction: 0.75)

    // MARK: - Easing Convenience

    /// Things appearing — easeOut with given duration token
    static func enter(duration: Double = normal) -> Animation {
        .easeOut(duration: duration)
    }

    /// Things leaving — easeIn with given duration token
    static func exit(duration: Double = normal) -> Animation {
        .easeIn(duration: duration)
    }

    /// Things transitioning — easeInOut with given duration token
    static func move(duration: Double = normal) -> Animation {
        .easeInOut(duration: duration)
    }
}
