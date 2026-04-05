//
//  ObsidianView.swift
//  AgenticIsland
//
//  Displays today's Obsidian tasks and meetings in the notch
//

import SwiftUI

struct ObsidianView: View {
    @ObservedObject var obsidian: ObsidianService

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                // Meetings section
                if !obsidian.meetings.isEmpty {
                    meetingsSection
                }

                // Nudge / focus hint
                if let nudge = obsidian.nudge {
                    nudgeSection(nudge)
                }

                // Tasks section
                tasksSection

                // Vault info
                if obsidian.dailyTasks.isEmpty && obsidian.meetings.isEmpty && obsidian.nudge == nil {
                    vaultHint
                }
            }
            .padding(.vertical, 4)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Meetings

    private var meetingsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Meetings", systemImage: "calendar")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(TerminalColors.warmSilver)

            ForEach(obsidian.meetings) { meeting in
                HStack(spacing: 8) {
                    Circle()
                        .fill(meeting.isRequired ? TerminalColors.coral : TerminalColors.stoneGray)
                        .frame(width: 6, height: 6)

                    Text(meeting.time)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(TerminalColors.warmSilver)
                        .frame(width: 100, alignment: .leading)

                    Text(meeting.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(TerminalColors.ivory)
                        .lineLimit(1)
                }
                .padding(.leading, 4)
            }
        }
    }

    // MARK: - Nudge

    private func nudgeSection(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 10))
                .foregroundColor(TerminalColors.coral)
                .padding(.top, 2)

            Text(text)
                .font(.system(size: 11))
                .foregroundColor(TerminalColors.warmSilver)
                .lineLimit(3)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(TerminalColors.surface.opacity(0.5))
        )
    }

    // MARK: - Vault Hint

    private var vaultHint: some View {
        VStack(spacing: 4) {
            Text("No data found")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(TerminalColors.stoneGray)
            Text("Set vault path in Settings")
                .font(.system(size: 11))
                .foregroundColor(TerminalColors.stoneGray.opacity(0.6))
            Text("Expects Planning/ToDoList.md")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(TerminalColors.stoneGray.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Tasks

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Tasks", systemImage: "checklist")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(TerminalColors.warmSilver)

            if obsidian.dailyTasks.isEmpty {
                Text("No pending tasks")
                    .font(.system(size: 12))
                    .foregroundColor(TerminalColors.stoneGray)
                    .padding(.leading, 4)
            } else {
                ForEach(obsidian.dailyTasks) { task in
                    TaskRow(task: task)
                }
            }
        }
    }
}

// MARK: - Task Row

private struct TaskRow: View {
    let task: ObsidianTask

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 6, height: 6)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(task.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(TerminalColors.ivory)
                        .lineLimit(1)

                    if let status = task.status {
                        Text(status)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(TerminalColors.stoneGray)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(TerminalColors.surface)
                            )
                    }
                }

                HStack(spacing: 8) {
                    Text(task.type)
                        .font(.system(size: 10))
                        .foregroundColor(typeColor)

                    if let daysInfo = task.daysInfo {
                        Text(daysInfo)
                            .font(.system(size: 10, weight: task.isOverdue ? .bold : .regular))
                            .foregroundColor(task.isOverdue ? TerminalColors.red : TerminalColors.stoneGray)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, 4)
        .padding(.vertical, 2)
    }

    private var priorityColor: Color {
        if task.isOverdue { return TerminalColors.red }
        guard let due = task.due, due != "none" else { return TerminalColors.stoneGray }
        // Due within 7 days = orange, otherwise green
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let dueDate = formatter.date(from: due) else { return TerminalColors.stoneGray }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        if days <= 7 { return TerminalColors.coral }
        return TerminalColors.green
    }

    private var typeColor: Color {
        switch task.type {
        case "Main": return TerminalColors.coral
        case "Conference": return TerminalColors.blue
        case "Career": return TerminalColors.magenta
        case "Chore": return TerminalColors.warmSilver
        default: return TerminalColors.stoneGray
        }
    }
}
