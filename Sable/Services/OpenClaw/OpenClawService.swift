import Foundation
import Observation

/// Central service that owns OpenClaw detection, control, and polling.
///
/// Polling uses a layered strategy:
/// - **Foreground** (Dashboard visible): every 5 seconds
/// - **Background** (other pages): every 30 seconds
/// - **Post-action burst**: every 2 seconds for 10 seconds after Start/Stop/Restart
@MainActor
@Observable
final class OpenClawService {

    // MARK: - Transition

    /// Describes an in-flight control action whose outcome hasn't been confirmed yet.
    enum TransitionAction: Equatable {
        case starting
        case stopping
        case restarting
    }

    // MARK: - Published State

    private(set) var status: OpenClawStatus = .notInstalled
    private(set) var isPerformingAction = false
    /// Non-nil while waiting for the status to reflect a control action.
    private(set) var transition: TransitionAction?

    /// True when any control action is in flight or waiting for confirmation.
    var isBusy: Bool {
        isPerformingAction || transition != nil
    }

    // MARK: - Dependencies

    let detector: OpenClawDetector
    let controller: OpenClawController

    // MARK: - Polling State

    private var pollingTask: Task<Void, Never>?
    private var burstEndTime: Date?
    private var isForeground = false
    /// The status snapshot taken right before a control action, used to detect change.
    private var preActionStatus: OpenClawStatus?
    /// Safety timeout for clearing a stuck transition.
    private var transitionDeadline: Date?

    private var currentInterval: Duration {
        if let burstEnd = burstEndTime, Date.now < burstEnd {
            return .seconds(2)
        }
        return isForeground ? .seconds(5) : .seconds(30)
    }

    // MARK: - Init

    init(
        detector: OpenClawDetector = OpenClawDetector(),
        controller: OpenClawController = OpenClawController()
    ) {
        self.detector = detector
        self.controller = controller
    }

    // MARK: - Lifecycle

    func startPolling() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                let interval = self?.currentInterval ?? .seconds(30)
                try? await Task.sleep(for: interval)
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Call when Dashboard becomes visible/hidden to adjust polling frequency.
    func setForeground(_ foreground: Bool) {
        isForeground = foreground
    }

    // MARK: - Detection

    func refresh() async {
        let newStatus = await detector.detect()
        status = newStatus
        checkTransitionResolved(newStatus)
    }

    // MARK: - Control Actions

    func start() async {
        guard status.isOnboarded, !isBusy else { return }
        beginTransition(.starting)
        isPerformingAction = true
        let result = await controller.start()
        isPerformingAction = false

        if !result.success {
            status = .error(message: result.output)
            clearTransition()
        }

        startBurstPolling()
    }

    func stop() async {
        guard status.isRunning, !isBusy else { return }
        beginTransition(.stopping)
        isPerformingAction = true
        let result = await controller.stop()
        isPerformingAction = false

        if !result.success {
            status = .error(message: result.output)
            clearTransition()
        }

        startBurstPolling()
    }

    func restart() async {
        guard status.isOnboarded, !isBusy else { return }
        beginTransition(.restarting)
        isPerformingAction = true
        let result = await controller.restart()
        isPerformingAction = false

        if !result.success {
            status = .error(message: result.output)
            clearTransition()
        }

        startBurstPolling()
    }

    // MARK: - Transition Management

    private func beginTransition(_ action: TransitionAction) {
        preActionStatus = status
        transition = action
        transitionDeadline = Date.now.addingTimeInterval(15)
    }

    private func clearTransition() {
        transition = nil
        preActionStatus = nil
        transitionDeadline = nil
    }

    /// Called after each poll to check if the status has actually changed from pre-action.
    private func checkTransitionResolved(_ newStatus: OpenClawStatus) {
        guard transition != nil else { return }

        // Safety: clear if deadline passed
        if let deadline = transitionDeadline, Date.now >= deadline {
            clearTransition()
            return
        }

        // Check if status actually changed from what it was before the action
        guard let pre = preActionStatus else {
            clearTransition()
            return
        }

        // Transition resolves when status differs from pre-action snapshot
        if newStatus != pre {
            clearTransition()
        }
    }

    // MARK: - Burst Polling

    /// After a control action, poll rapidly for 10 seconds to catch state changes quickly.
    private func startBurstPolling() {
        burstEndTime = Date.now.addingTimeInterval(10)
    }
}
