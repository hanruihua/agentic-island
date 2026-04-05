//
//  ActiveSessionScanner.swift
//  AgenticIsland
//
//  Scans ~/.claude/sessions/ on startup to discover already-running
//  Claude Code CLI sessions and register them in SessionStore.
//

import Foundation
import os.log

enum ActiveSessionScanner {
    private static let logger = Logger(subsystem: "com.claudeisland", category: "Scanner")

    /// Scan ~/.claude/sessions/ for active Claude Code sessions.
    /// Each file is named {pid}.json and contains sessionId, cwd, pid, etc.
    /// Only returns entries whose PID is still alive.
    static func discoverActiveSessions() -> [DiscoveredSession] {
        let sessionsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/sessions")

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: sessionsDir,
            includingPropertiesForKeys: nil
        ) else {
            logger.info("No sessions directory found")
            return []
        }

        var discovered: [DiscoveredSession] = []

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pid = json["pid"] as? Int,
                  let sessionId = json["sessionId"] as? String,
                  let cwd = json["cwd"] as? String else {
                continue
            }

            // Check if the process is still running
            guard isProcessAlive(pid: pid) else {
                logger.debug("Session \(sessionId.prefix(8), privacy: .public) pid \(pid) not alive, skipping")
                continue
            }

            logger.info("Discovered active session \(sessionId.prefix(8), privacy: .public) pid \(pid) at \(cwd, privacy: .public)")
            discovered.append(DiscoveredSession(
                sessionId: sessionId,
                cwd: cwd,
                pid: pid
            ))
        }

        logger.info("Discovered \(discovered.count) active session(s)")
        return discovered
    }

    private static func isProcessAlive(pid: Int) -> Bool {
        // kill(pid, 0) returns 0 if process exists and we have permission to signal it
        kill(Int32(pid), 0) == 0
    }
}

struct DiscoveredSession: Sendable {
    let sessionId: String
    let cwd: String
    let pid: Int
}
