//
//  UsageTracker.swift
//  AgenticIsland
//
//  Reads Claude Code usage data from /tmp/agentic-island-usage.json,
//  written by the statusline command which receives real rate limit data.
//

import Combine
import Foundation
import os.log

/// Usage data from Claude Code's statusline
struct UsageData: Equatable {
    var contextWindow: Double = 0      // 0–100
    var fiveHour: Double = 0           // 0–100
    var fiveHourResetsAt: Date? = nil
    var sevenDay: Double = 0           // 0–100
    var sevenDayResetsAt: Date? = nil
    var model: String = ""
    var costUSD: Double = 0
}

@MainActor
class UsageTracker: ObservableObject {
    static let shared = UsageTracker()

    private static let logger = Logger(subsystem: "com.claudeisland", category: "UsageTracker")
    private static let usageFilePath = "/tmp/agentic-island-usage.json"

    @Published var usage = UsageData()

    /// Whether we have any data
    @Published var hasData: Bool = false

    private var refreshTimer: Timer?

    private init() {}

    func startTracking(sessions: [SessionState]) {
        refresh()
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    func refresh(sessions: [SessionState]? = nil) {
        readUsageFile()
    }

    func stopTracking() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Private

    private func readUsageFile() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: Self.usageFilePath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        var newUsage = UsageData()
        newUsage.contextWindow = (json["context_window"] as? Double) ?? 0
        newUsage.fiveHour = (json["five_hour"] as? Double) ?? 0
        newUsage.sevenDay = (json["seven_day"] as? Double) ?? 0
        newUsage.model = (json["model"] as? String) ?? ""
        newUsage.costUSD = (json["cost_usd"] as? Double) ?? 0

        if let ts = json["five_hour_resets_at"] as? Double, ts > 0 {
            newUsage.fiveHourResetsAt = Date(timeIntervalSince1970: ts)
        }
        if let ts = json["seven_day_resets_at"] as? Double, ts > 0 {
            newUsage.sevenDayResetsAt = Date(timeIntervalSince1970: ts)
        }

        usage = newUsage
        hasData = true
    }
}
