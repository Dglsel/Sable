import Foundation
import os

/// Reads skill data from `openclaw skills list --json`.
/// Also handles registry search and install via `sable` CLI.
struct SkillService {

    private static let logger = Logger(subsystem: "ai.sable", category: "SkillService")

    // MARK: - Model

    struct SkillInfo: Identifiable, Equatable {
        let name: String
        let description: String
        let emoji: String
        let eligible: Bool
        let disabled: Bool
        let source: String
        let bundled: Bool
        let homepage: String?
        let missingBins: [String]
        /// The actual folder name / registry slug. For workspace skills this may differ from `name`.
        let registrySlug: String?
        /// The actual folder name on disk (e.g. "stealth-browser-1.0.0"). Nil for bundled skills.
        let workspaceFolderName: String?
        /// True if the skill came from the registry (has _meta.json) or is bundled.
        let fromRegistry: Bool

        var id: String { name }

        var status: Status {
            if disabled { return .disabled }
            if !eligible { return .missing }
            return .ready
        }

        enum Status: String {
            case ready
            case missing
            case disabled

            var label: String {
                switch self {
                case .ready: "Ready"
                case .missing: "Missing"
                case .disabled: "Disabled"
                }
            }
        }

        var displayName: String {
            "\(emoji) \(name)"
        }
    }

    // MARK: - Search Result

    struct SearchResult: Identifiable, Equatable {
        let slug: String
        let name: String
        let score: Double

        var id: String { slug }
    }

    // MARK: - Skill Detail (from registry inspect)

    struct SkillDetail: Equatable {
        let slug: String
        let name: String
        let summary: String
        let owner: String
        let version: String
        let license: String
        let created: String
        let updated: String
    }

    // MARK: - Install Result

    enum InstallResult: Equatable {
        case success(slug: String, path: String)
        case failure(message: String)
    }

    // MARK: - Fetch Installed Skills

    static func fetchSkills() async -> [SkillInfo] {
        // Resolve MainActor-isolated values before jumping to a background thread.
        let (binary, env) = await MainActor.run {
            (GatewayService.findBinary(), GatewayService.buildSubprocessEnvironment())
        }
        guard let binary else {
            logger.warning("Cannot find openclaw binary for skill list")
            return []
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Self.runProcess(
                    binary: binary,
                    arguments: ["skills", "list", "--json"],
                    environment: env,
                    timeout: 15
                )
                guard result.exitCode == 0 else {
                    logger.warning("openclaw skills list exited with \(result.exitCode)")
                    continuation.resume(returning: [])
                    return
                }
                let skills = parseSkillsJSON(Data((result.stdout).utf8))
                continuation.resume(returning: skills)
            }
        }
    }

    // MARK: - Registry Search

    @MainActor
    static func searchRegistry(query: String) async -> [SearchResult] {
        guard let binary = findSableBinary() else {
            logger.warning("Cannot find sable binary for search")
            return []
        }
        let env = GatewayService.buildSubprocessEnvironment()

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Self.runProcess(
                    binary: binary, arguments: ["search", query, "--no-input"],
                    environment: env, timeout: 15
                )
                let results = parseSearchOutput(result.stdout)
                continuation.resume(returning: results)
            }
        }
    }

    // MARK: - Registry Inspect

    @MainActor
    static func inspectSkill(slug: String) async -> SkillDetail? {
        guard let binary = findSableBinary() else { return nil }
        let env = GatewayService.buildSubprocessEnvironment()

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Self.runProcess(
                    binary: binary, arguments: ["inspect", slug, "--no-input"],
                    environment: env, timeout: 15
                )
                guard result.exitCode == 0 else {
                    continuation.resume(returning: nil)
                    return
                }
                let detail = parseInspectOutput(result.stdout, slug: slug)
                continuation.resume(returning: detail)
            }
        }
    }

    // MARK: - Install from Registry

    @MainActor
    static func installSkill(slug: String) async -> InstallResult {
        guard let binary = findSableBinary() else {
            return .failure(message: "sable CLI not found. Install it with: npm install -g sable")
        }
        let env = GatewayService.buildSubprocessEnvironment()

        // Retry up to 2 times on rate limit errors, with increasing delay.
        let maxAttempts = 3
        for attempt in 1...maxAttempts {
            let installResult: InstallResult = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    let result = Self.runProcess(
                        binary: binary, arguments: ["install", slug, "--no-input", "--force"],
                        environment: env, timeout: 60
                    )

                    logger.info("sable install attempt=\(attempt) exit=\(result.exitCode) stdout=\(result.stdout.prefix(200))")

                    if result.timedOut {
                        continuation.resume(returning: .failure(message: "Install timed out after 60 seconds. The registry may be slow — try again."))
                    } else if result.exitCode == 0 {
                        let path = extractInstallPath(result.stdout) ?? ""
                        continuation.resume(returning: .success(slug: slug, path: path))
                    } else {
                        let userMessage = humanReadableError(stdout: result.stdout, stderr: result.stderr, slug: slug)
                        continuation.resume(returning: .failure(message: userMessage))
                    }
                }
            }

            // If success or non-rate-limit error, return immediately
            if case .success = installResult { return installResult }
            if case .failure(let msg) = installResult {
                let isRateLimit = msg.lowercased().contains("rate limit")
                if !isRateLimit || attempt == maxAttempts {
                    return installResult
                }
                // Rate limited — wait before retrying
                let delay = attempt == 1 ? 3 : 6
                logger.info("Rate limited, retrying in \(delay)s (attempt \(attempt)/\(maxAttempts))")
                try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
            }
        }

        return .failure(message: "Install failed after \(maxAttempts) attempts due to rate limiting. Try again in a minute.")
    }

    // MARK: - Uninstall

    enum UninstallResult: Equatable {
        case success
        case failure(message: String)
    }

    @MainActor
    static func uninstallSkill(slug: String) async -> UninstallResult {
        guard let binary = findSableBinary() else {
            return .failure(message: "sable CLI not found.")
        }
        let env = GatewayService.buildSubprocessEnvironment()

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Self.runProcess(
                    binary: binary, arguments: ["uninstall", slug, "--yes"],
                    environment: env, timeout: 30
                )

                logger.info("sable uninstall exit=\(result.exitCode) stdout=\(result.stdout.prefix(200))")

                if result.exitCode == 0 {
                    continuation.resume(returning: .success)
                } else {
                    let msg = result.stderr.isEmpty ? result.stdout : result.stderr
                    continuation.resume(returning: .failure(message: String(msg.prefix(120)).isEmpty ? "Uninstall failed." : String(msg.prefix(120))))
                }
            }
        }
    }

    // MARK: - Safe Process Runner

    /// Runs a CLI process with pipe-safe reading (no deadlock) and a timeout.
    /// Returns stdout, stderr, exit code, and whether it timed out.
    private struct ProcessResult {
        let stdout: String
        let stderr: String
        let exitCode: Int32
        let timedOut: Bool
    }

    private final class PipeReadResult: @unchecked Sendable {
        private let lock = NSLock()
        private var stored = Data()

        func set(_ data: Data) {
            lock.lock()
            stored = data
            lock.unlock()
        }

        func get() -> Data {
            lock.lock()
            defer { lock.unlock() }
            return stored
        }
    }

    private static func runProcess(
        binary: String,
        arguments: [String],
        environment: [String: String],
        timeout: TimeInterval
    ) -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = arguments
        process.environment = environment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Collect pipe data on separate threads to prevent deadlock.
        // If the process writes enough to fill a pipe buffer (~64KB) while
        // the reader hasn't started, waitUntilExit() will block forever.
        let stdoutResult = PipeReadResult()
        let stderrResult = PipeReadResult()
        let stdoutQueue = DispatchQueue(label: "sable.stdout")
        let stderrQueue = DispatchQueue(label: "sable.stderr")

        stdoutQueue.async {
            stdoutResult.set(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
        }
        stderrQueue.async {
            stderrResult.set(stderrPipe.fileHandleForReading.readDataToEndOfFile())
        }

        do {
            try process.run()
        } catch {
            return ProcessResult(stdout: "", stderr: error.localizedDescription, exitCode: -1, timedOut: false)
        }

        // Timeout: kill process if it exceeds the limit
        let deadline = DispatchTime.now() + timeout
        let timedOut: Bool
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            process.waitUntilExit()
            semaphore.signal()
        }
        if semaphore.wait(timeout: deadline) == .timedOut {
            process.terminate()
            timedOut = true
        } else {
            timedOut = false
        }

        // Wait for pipe readers to finish
        stdoutQueue.sync {}
        stderrQueue.sync {}

        let stdout = cleanCLIOutput(String(data: stdoutResult.get(), encoding: .utf8) ?? "")
        let stderr = cleanCLIOutput(String(data: stderrResult.get(), encoding: .utf8) ?? "")

        return ProcessResult(
            stdout: stdout,
            stderr: stderr,
            exitCode: timedOut ? -1 : process.terminationStatus,
            timedOut: timedOut
        )
    }

    // MARK: - Binary Location

    @MainActor
    private static func findSableBinary() -> String? {
        let knownPaths = [
            "/opt/homebrew/bin/sable",
            "/usr/local/bin/sable"
        ]
        for path in knownPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        let env = GatewayService.buildSubprocessEnvironment()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["sable"]
        process.environment = env
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        var data = Data()
        let readQueue = DispatchQueue(label: "sable.which.stdout")
        readQueue.async { data = pipe.fileHandleForReading.readDataToEndOfFile() }
        do {
            try process.run()
            process.waitUntilExit()
            readQueue.sync {}
            guard process.terminationStatus == 0 else { return nil }
            let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (path?.isEmpty == false) ? path : nil
        } catch {
            return nil
        }
    }

    // MARK: - Parse Helpers

    private static func parseSearchOutput(_ raw: String) -> [SearchResult] {
        let lines = raw.components(separatedBy: "\n")
        var results: [SearchResult] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("- ") || trimmed.hasPrefix("✔") || trimmed.hasPrefix("✖") {
                continue
            }

            guard let scoreStart = trimmed.lastIndex(of: "("),
                  let scoreEnd = trimmed.lastIndex(of: ")"),
                  scoreStart < scoreEnd else { continue }

            let scoreStr = String(trimmed[trimmed.index(after: scoreStart)..<scoreEnd])
            guard let score = Double(scoreStr) else { continue }

            let beforeScore = String(trimmed[trimmed.startIndex..<scoreStart])
                .trimmingCharacters(in: .whitespaces)

            let parts = beforeScore.split(separator: " ", maxSplits: 1)
            guard let slugPart = parts.first else { continue }

            let slug = String(slugPart)
            let name = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : slug

            results.append(SearchResult(slug: slug, name: name, score: score))
        }

        return results
    }

    private static func parseInspectOutput(_ raw: String, slug: String) -> SkillDetail? {
        let lines = raw.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("- ") }

        guard !lines.isEmpty else { return nil }

        let headerParts = lines[0].split(separator: " ", maxSplits: 1)
        let name = headerParts.count > 1 ? String(headerParts[1]).trimmingCharacters(in: .whitespaces) : slug

        func field(_ prefix: String) -> String {
            for line in lines {
                if line.hasPrefix(prefix) {
                    return String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                }
            }
            return ""
        }

        return SkillDetail(
            slug: slug,
            name: name,
            summary: field("Summary:"),
            owner: field("Owner:"),
            version: field("Latest:"),
            license: field("License:"),
            created: field("Created:"),
            updated: field("Updated:")
        )
    }

    static func extractSlugFromInput(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 1. sable.ai URL — extract slug from the last path segment.
        //    Actual registry URL format: https://sable.ai/<author>/<slug>
        //    Also handles legacy:        https://sable.ai/skills/<slug>
        //    With trailing slash, query string, or fragment.
        if let url = URL(string: trimmed),
           let host = url.host?.lowercased(),
           host.contains("sable") {
            // url.path gives e.g. "/kys42/stock-market-pro" or "/skills/my-skill"
            let segments = url.path
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .split(separator: "/")
                .map(String.init)
            // Take the last non-empty segment as slug
            if let last = segments.last, isValidSlug(last.lowercased()) {
                return last.lowercased()
            }
        }

        // 2. Bare slug: single token like "self-improving-agent"
        if !trimmed.contains(" ") && !trimmed.contains("/") && !trimmed.contains(".") {
            let lower = trimmed.lowercased()
            if isValidSlug(lower) {
                return lower
            }
        }

        return nil
    }

    /// Validates that a string looks like a registry slug (lowercase alphanumeric + hyphens).
    private static func isValidSlug(_ value: String) -> Bool {
        let allowed = CharacterSet.lowercaseLetters
            .union(.decimalDigits)
            .union(CharacterSet(charactersIn: "-"))
        return !value.isEmpty && value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func cleanCLIOutput(_ raw: String) -> String {
        var cleaned = raw.replacingOccurrences(
            of: "\\x1B\\[[0-9;]*[A-Za-z]",
            with: "",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(
            of: "^[\\-✔✖]\\s+",
            with: "",
            options: .regularExpression
        )
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractInstallPath(_ output: String) -> String? {
        guard let arrowRange = output.range(of: "-> ") else { return nil }
        let pathStart = arrowRange.upperBound
        let path = String(output[pathStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    private static func humanReadableError(stdout: String, stderr: String, slug: String) -> String {
        let combined = "\(stdout) \(stderr)".lowercased()

        if combined.contains("not found") {
            return "Skill \"\(slug)\" was not found in the registry."
        }
        if combined.contains("rate") || combined.contains("remaining:") {
            return "Registry rate limit reached. Please wait a moment and try again."
        }
        if combined.contains("network") || combined.contains("econnrefused") || combined.contains("timeout") {
            return "Could not reach the registry. Check your network connection."
        }
        if combined.contains("eacces") || combined.contains("permission") {
            return "Permission denied. Check folder permissions for the skills directory."
        }

        let fallback = stdout.isEmpty ? stderr : stdout
        let truncated = String(fallback.prefix(120))
        return truncated.isEmpty ? "Install failed. Check the logs for details." : truncated
    }

    // MARK: - Parse Skills JSON

    private static func parseSkillsJSON(_ data: Data) -> [SkillInfo] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let skills = json["skills"] as? [[String: Any]] else {
            return []
        }

        // Build a name→folderName mapping for workspace skills.
        // Folder name = registry slug, but SKILL.md inside may define a different `name`.
        let nameToFolder = buildWorkspaceNameMap()

        return skills.compactMap { dict -> SkillInfo? in
            guard let name = dict["name"] as? String,
                  let description = dict["description"] as? String else { return nil }

            let missing = dict["missing"] as? [String: Any]
            let missingBins = (missing?["bins"] as? [String]) ?? []
            let isBundled = dict["bundled"] as? Bool ?? false

            // For workspace skills, use _meta.json slug (registry) or folder name (local import)
            let slug: String?
            if isBundled {
                slug = nil
            } else if let info = nameToFolder[name] {
                // Prefer _meta.json slug (authoritative registry slug), fall back to folder name
                slug = info.metaSlug ?? info.folderName
            } else {
                slug = nil
            }

            // Determine if skill is from registry: bundled always yes, workspace only if _meta.json exists
            let isFromRegistry = isBundled || (nameToFolder[name]?.metaSlug != nil)

            return SkillInfo(
                name: name,
                description: description,
                emoji: dict["emoji"] as? String ?? "📦",
                eligible: dict["eligible"] as? Bool ?? false,
                disabled: dict["disabled"] as? Bool ?? false,
                source: dict["source"] as? String ?? "unknown",
                bundled: isBundled,
                homepage: dict["homepage"] as? String,
                missingBins: missingBins,
                registrySlug: slug,
                workspaceFolderName: isBundled ? nil : nameToFolder[name]?.folderName,
                fromRegistry: isFromRegistry
            )
        }
    }

    /// Info resolved from a workspace skill folder.
    private struct WorkspaceFolderInfo {
        let folderName: String
        /// Registry slug from `_meta.json`, nil if locally imported.
        let metaSlug: String?
    }

    /// Scans ~/.openclaw/workspace/skills/ and reads each folder's SKILL.md `name:` field
    /// and `_meta.json` slug to build a [displayName → WorkspaceFolderInfo] mapping.
    private static func buildWorkspaceNameMap() -> [String: WorkspaceFolderInfo] {
        let skillsDir = WorkspaceService.workspaceDirectory.appendingPathComponent("skills")
        let fm = FileManager.default
        guard let folders = try? fm.contentsOfDirectory(atPath: skillsDir.path) else { return [:] }

        var map: [String: WorkspaceFolderInfo] = [:]
        for folder in folders {
            // Skip hidden folders like .DS_Store
            guard !folder.hasPrefix(".") else { continue }

            let folderURL = skillsDir.appendingPathComponent(folder)
            let skillMD = folderURL.appendingPathComponent("SKILL.md")
            guard let content = try? String(contentsOf: skillMD, encoding: .utf8) else { continue }

            // Parse `name:` from YAML frontmatter
            var skillName: String?
            for line in content.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("name:") {
                    let name = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { skillName = name }
                    break
                }
            }

            // Read _meta.json for registry slug (only present for registry-installed skills)
            var metaSlug: String?
            let metaURL = folderURL.appendingPathComponent("_meta.json")
            if let metaData = try? Data(contentsOf: metaURL),
               let metaJSON = try? JSONSerialization.jsonObject(with: metaData) as? [String: Any],
               let slug = metaJSON["slug"] as? String, !slug.isEmpty {
                metaSlug = slug
            }

            let displayName = skillName ?? folder
            map[displayName] = WorkspaceFolderInfo(folderName: folder, metaSlug: metaSlug)
        }
        return map
    }
}
