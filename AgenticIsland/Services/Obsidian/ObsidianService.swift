//
//  ObsidianService.swift
//  AgenticIsland
//
//  Reads today's tasks and meetings from Obsidian vault
//

import Combine
import Foundation

struct ObsidianTask: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let type: String        // Main, Chore, Career, etc.
    let due: String?        // e.g. "2026-04-15"
    let status: String?     // e.g. "Writing", "Under Review"
    let isCompleted: Bool
    let isOverdue: Bool
    let daysInfo: String?   // e.g. "4 days overdue", "7 days left"
}

struct ObsidianMeeting: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let time: String        // e.g. "7:00 - 11:00"
    let isRequired: Bool
}

@MainActor
class ObsidianService: ObservableObject {
    static let shared = ObsidianService()

    @Published var dailyTasks: [ObsidianTask] = []
    @Published var meetings: [ObsidianMeeting] = []
    @Published var nudge: String?
    @Published var lastUpdated: Date?

    private var vaultPath: String
    private var fileWatcher: DispatchSourceFileSystemObject?
    private var refreshTimer: Timer?

    private init() {
        let saved = AppSettings.obsidianVaultPath
        vaultPath = saved.isEmpty ? "/Users/han/tech/han" : saved
        refresh()
        startWatching()
        // Refresh every 5 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func updateVaultPath(_ path: String) {
        vaultPath = path
        stopWatching()
        refresh()
        startWatching()
    }

    func refresh() {
        loadTasks()
        loadMeetings()
        lastUpdated = Date()
    }

    // MARK: - Tasks from ToDoList.md

    private func loadTasks() {
        let todoPath = "\(vaultPath)/Planning/ToDoList.md"
        guard let content = try? String(contentsOfFile: todoPath, encoding: .utf8) else {
            dailyTasks = []
            nudge = nil
            return
        }

        var tasks: [ObsidianTask] = []
        let today = Calendar.current.startOfDay(for: Date())
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let lines = content.components(separatedBy: "\n")
        for line in lines {
            // Match task lines: - [ ] or - [x] with [type:: X]
            guard line.contains("[type::") else { continue }

            let isCompleted = line.contains("[x]")
            if isCompleted { continue } // Skip completed tasks

            // Extract type
            guard let type = extractField(from: line, field: "type") else { continue }

            // Extract title (text before first [type/due/status/progress tag)
            let title = extractTitle(from: line)

            // Extract optional fields
            let due = extractField(from: line, field: "due")
            let status = extractField(from: line, field: "status")

            // Calculate days info
            var isOverdue = false
            var daysInfo: String? = nil
            if let due = due, due != "none", let dueDate = dateFormatter.date(from: due) {
                let daysDiff = Calendar.current.dateComponents([.day], from: today, to: dueDate).day ?? 0
                if daysDiff < 0 {
                    isOverdue = true
                    daysInfo = "\(abs(daysDiff))d overdue"
                } else if daysDiff == 0 {
                    daysInfo = "Today"
                } else if daysDiff == 1 {
                    daysInfo = "1 day left"
                } else {
                    daysInfo = "\(daysDiff) days left"
                }
            }

            tasks.append(ObsidianTask(
                title: title,
                type: type,
                due: due,
                status: status,
                isCompleted: isCompleted,
                isOverdue: isOverdue,
                daysInfo: daysInfo
            ))
        }

        // Sort: overdue first, then by due date (soonest first), then no-deadline last
        dailyTasks = tasks.sorted { a, b in
            if a.isOverdue != b.isOverdue { return a.isOverdue }
            if a.due == nil || a.due == "none" { return false }
            if b.due == nil || b.due == "none" { return true }
            return (a.due ?? "") < (b.due ?? "")
        }

        // Load nudge from daily note
        loadNudge()
    }

    private func loadNudge() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayStr = dateFormatter.string(from: Date())
        let dailyPath = "\(vaultPath)/Planning/Daily/\(todayStr).md"
        guard let content = try? String(contentsOfFile: dailyPath, encoding: .utf8) else {
            nudge = nil
            return
        }

        // Extract nudge section
        if let nudgeRange = content.range(of: "> **Nudge**") {
            let afterNudge = String(content[nudgeRange.upperBound...])
            let nudgeLines = afterNudge.components(separatedBy: "\n")
            var nudgeText = ""
            for line in nudgeLines.dropFirst() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix(">") {
                    let cleaned = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                    if !cleaned.isEmpty {
                        nudgeText += cleaned + " "
                    }
                } else {
                    break
                }
            }
            nudge = nudgeText.trimmingCharacters(in: .whitespaces)
            if nudge?.isEmpty == true { nudge = nil }
        } else {
            nudge = nil
        }
    }

    // MARK: - Meetings from TimeTable.md

    private func loadMeetings() {
        let timetablePath = "\(vaultPath)/Planning/TimeTable.md"
        guard let content = try? String(contentsOfFile: timetablePath, encoding: .utf8) else {
            meetings = []
            return
        }

        let dayOfWeek = currentDayOfWeek()
        var result: [ObsidianMeeting] = []

        // Parse the Day-Specific Overrides table
        let lines = content.components(separatedBy: "\n")
        var inTable = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Detect table start (after header row and separator)
            if trimmed.hasPrefix("| :") || trimmed.hasPrefix("| -") {
                inTable = true
                continue
            }

            if trimmed.hasPrefix("| Day") {
                continue // Skip header
            }

            if inTable && trimmed.hasPrefix("|") {
                let columns = trimmed.components(separatedBy: "|")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                guard columns.count >= 4 else { continue }

                let day = columns[0]
                let time = columns[1]
                let eventName = columns[2]
                let isRequired = columns.count > 3 && columns[3] == "Yes"

                // Match current day of week
                if day.lowercased() == dayOfWeek.lowercased() && !eventName.isEmpty {
                    result.append(ObsidianMeeting(
                        title: eventName,
                        time: time,
                        isRequired: isRequired
                    ))
                }
            }

            // End of table
            if inTable && !trimmed.hasPrefix("|") && !trimmed.isEmpty {
                inTable = false
            }
        }

        meetings = result
    }

    // MARK: - File Watching

    private func stopWatching() {
        fileWatcher?.cancel()
        fileWatcher = nil
    }

    private func startWatching() {
        let todoPath = "\(vaultPath)/Planning/ToDoList.md"
        let fd = open(todoPath, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.refresh()
            }
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        fileWatcher = source
    }

    // MARK: - Helpers

    private func extractField(from line: String, field: String) -> String? {
        let pattern = "\\[\(field)::\\s*([^\\]]+)\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else { return nil }
        return String(line[range]).trimmingCharacters(in: .whitespaces)
    }

    private func extractTitle(from line: String) -> String {
        var text = line
        // Remove checkbox prefix
        if let checkboxRange = text.range(of: "- [") {
            if let closeBracket = text[checkboxRange.upperBound...].range(of: "] ") {
                text = String(text[closeBracket.upperBound...])
            }
        }
        // Remove inline fields and link references
        text = text.replacingOccurrences(of: "\\s*\\[(?:type|due|progress|status)::\\s*[^\\]]*\\]", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\s*—.*$", with: "", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespaces)
        // Remove emoji prefix if present
        if let first = text.unicodeScalars.first, first.properties.isEmoji && first.value > 0x7F {
            text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        return text
    }

    private func currentDayOfWeek() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }
}
