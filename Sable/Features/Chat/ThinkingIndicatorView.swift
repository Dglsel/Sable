import SwiftUI

/// Animated "thinking" indicator shown while waiting for an agent response.
/// Three dots with a rolling wave animation — each dot pulses in sequence,
/// creating a smooth left-to-right flow rather than all firing at once.
/// After 2 seconds, a low-key elapsed timer fades in below the dots.
/// When a tool call is active, displays the tool name as a status label.
struct ThinkingIndicatorView: View {
    var activeToolName: String?

    @State private var phase: Int = 0
    @State private var elapsedSeconds = 0
    @State private var showTimer = false
    @State private var timerTask: Task<Void, Never>?
    @State private var waveTask: Task<Void, Never>?
    @State private var iconPulse = false

    private let dotCount = 3
    /// How much each dot shrinks/fades when not in the active phase.
    private let inactiveScale: CGFloat = 0.55
    private let inactiveOpacity: Double = 0.20

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Sparkles icon with a gentle breathing pulse
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SableTheme.interactive)
                .frame(width: 24, height: 24)
                .padding(.top, 2)
                .scaleEffect(iconPulse ? 1.08 : 0.96)
                .opacity(iconPulse ? 0.9 : 0.6)
                .animation(
                    .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                    value: iconPulse
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    // Rolling wave dots
                    HStack(spacing: 5) {
                        ForEach(0..<dotCount, id: \.self) { index in
                            let isActive = phase == index
                            Circle()
                                .fill(Color.primary)
                                .frame(width: 6, height: 6)
                                .scaleEffect(isActive ? 1.0 : inactiveScale)
                                .opacity(isActive ? 0.70 : inactiveOpacity)
                                .animation(.spring(response: 0.32, dampingFraction: 0.6), value: phase)
                        }
                    }

                    // Elapsed timer — fades in after 2s
                    if showTimer {
                        Text("\(elapsedSeconds)s")
                            .font(SableTypography.caption)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                            .transition(.opacity.combined(with: .offset(x: -4)))
                    }
                }

                // Active tool call label
                if let toolName = activeToolName {
                    Text(toolDisplayName(toolName))
                        .font(SableTypography.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity.combined(with: .offset(y: -2)))
                }
            }
            .padding(.top, 9)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            phase = 0
            elapsedSeconds = 0
            showTimer = false
            iconPulse = true
            timerTask?.cancel()
            waveTask?.cancel()

            // Rolling wave: advance the active dot every 380ms
            waveTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(380))
                    guard !Task.isCancelled else { break }
                    phase = (phase + 1) % dotCount
                }
            }

            // Elapsed seconds counter
            timerTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { break }
                    elapsedSeconds += 1
                    if elapsedSeconds >= 2 && !showTimer {
                        withAnimation(SableAnimation.exit(duration: SableAnimation.slow)) {
                            showTimer = true
                        }
                    }
                }
            }
        }
        .onDisappear {
            timerTask?.cancel()
            timerTask = nil
            waveTask?.cancel()
            waveTask = nil
        }
        .animation(SableAnimation.enter(duration: SableAnimation.fast), value: activeToolName)
    }

    /// Maps raw function names to user-friendly display labels.
    private func toolDisplayName(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.hasPrefix("retry:") {
            // Format: "retry:1/3" → "Retrying… (1/3)"
            let parts = String(lower.dropFirst(6))
            return "Retrying… (\(parts))"
        }
        if lower == "thinking" {
            return "Thinking…"
        }
        if lower.contains("search") || lower.contains("web_search") || lower.contains("brave") || lower.contains("perplexity") {
            return "Searching the web…"
        }
        if lower.contains("read") || lower.contains("fetch") || lower.contains("scrape") || lower.contains("browse") {
            return "Reading content…"
        }
        if lower.contains("execute") || lower.contains("run") || lower.contains("shell") || lower.contains("bash") || lower.contains("terminal") {
            return "Running command…"
        }
        if lower.contains("write") || lower.contains("save") || lower.contains("create_file") {
            return "Writing file…"
        }
        if lower.contains("edit") || lower.contains("patch") || lower.contains("replace") {
            return "Editing file…"
        }
        if lower.contains("list") || lower.contains("ls") || lower.contains("dir") {
            return "Listing files…"
        }
        // Fallback: show the raw name in a presentable way
        let cleaned = name.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        return "Using \(cleaned)…"
    }
}
