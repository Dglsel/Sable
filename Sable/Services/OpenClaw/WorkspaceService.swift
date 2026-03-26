import Foundation
import os

/// Reads and writes files in the OpenClaw workspace (`~/.openclaw/workspace/`).
struct WorkspaceService {

    private static let logger = Logger(subsystem: "ai.sable", category: "WorkspaceService")

    static var workspaceDirectory: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw")
            .appendingPathComponent("workspace")
    }

    /// Returns the full path for a workspace file.
    static func filePath(for section: AgentSection) -> URL {
        workspaceDirectory.appendingPathComponent(section.fileName)
    }

    /// Reads a workspace file and returns its content, or nil if not found.
    static func read(_ section: AgentSection) -> String? {
        let url = filePath(for: section)
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            logger.info("Read \(section.fileName): \(content.count) chars")
            return content
        } catch {
            logger.info("Cannot read \(section.fileName): \(error.localizedDescription)")
            return nil
        }
    }

    /// Writes content to a workspace file. Creates the file if it doesn't exist.
    /// Returns true on success.
    @discardableResult
    static func write(_ section: AgentSection, content: String) -> Bool {
        let url = filePath(for: section)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            logger.info("Wrote \(section.fileName): \(content.count) chars")
            return true
        } catch {
            logger.error("Failed to write \(section.fileName): \(error.localizedDescription)")
            return false
        }
    }

    /// Whether the workspace directory exists.
    static var workspaceExists: Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: workspaceDirectory.path, isDirectory: &isDir) && isDir.boolValue
    }
}
