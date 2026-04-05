//
//  UsageBarView.swift
//  AgenticIsland
//
//  Shows Claude Code rate limit usage bars with color-coded fill:
//  green → yellow → orange → red as usage increases.
//

import SwiftUI

struct UsageBarView: View {
    let usage: UsageData
    let hasData: Bool

    private let barHeight: CGFloat = 5
    private let cornerRadius: CGFloat = 2.5

    var body: some View {
        if hasData {
            VStack(spacing: 6) {
                // Rate limit bars
                HStack(spacing: 12) {
                    UsageMiniBar(
                        label: "5h",
                        percentage: usage.fiveHour,
                        resetsAt: usage.fiveHourResetsAt,
                        barHeight: barHeight,
                        cornerRadius: cornerRadius
                    )

                    UsageMiniBar(
                        label: "7d",
                        percentage: usage.sevenDay,
                        resetsAt: usage.sevenDayResetsAt,
                        barHeight: barHeight,
                        cornerRadius: cornerRadius
                    )
                }

                // Cost info
                if usage.costUSD > 0 {
                    HStack {
                        Text(usage.model)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(TerminalColors.stoneGray)
                        Spacer()
                        Text(String(format: "$%.2f", usage.costUSD))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(TerminalColors.stoneGray)
                    }
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Mini Bar

private struct UsageMiniBar: View {
    let label: String
    let percentage: Double
    let resetsAt: Date?
    let barHeight: CGFloat
    let cornerRadius: CGFloat

    private var ratio: Double { min(1.0, percentage / 100.0) }

    var body: some View {
        VStack(spacing: 3) {
            // Label + percentage
            HStack(spacing: 0) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(TerminalColors.stoneGray)

                Spacer()

                Text("\(Int(percentage))%")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(percentColor)

                if let resetsAt {
                    Text(" · \(resetTimeString(resetsAt))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(TerminalColors.stoneGray.opacity(0.6))
                }
            }

            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(TerminalColors.surface)
                        .frame(height: barHeight)

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(barColor)
                        .frame(width: max(0, geo.size.width * ratio), height: barHeight)
                        .animation(.easeInOut(duration: 0.5), value: ratio)
                }
            }
            .frame(height: barHeight)
        }
    }

    private var barColor: Color {
        colorForPercentage(percentage)
    }

    private var percentColor: Color {
        if percentage >= 85 {
            return TerminalColors.red
        } else if percentage >= 60 {
            return TerminalColors.coral
        } else {
            return TerminalColors.stoneGray
        }
    }

    private func resetTimeString(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        if interval <= 0 { return "now" }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)h\(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Color Scale

/// Maps 0–100 percentage to green → yellow → orange → red
private func colorForPercentage(_ pct: Double) -> Color {
    switch pct {
    case ..<30:
        return TerminalColors.green
    case 30..<60:
        let t = (pct - 30) / 30
        return Color(
            red: 0.45 + t * 0.55,
            green: 0.72 + t * 0.08,
            blue: 0.42 - t * 0.32
        )
    case 60..<85:
        let t = (pct - 60) / 25
        return Color(
            red: 1.0,
            green: 0.8 - t * 0.32,
            blue: 0.1 - t * 0.06
        )
    default:
        let t = min(1.0, (pct - 85) / 15)
        return Color(
            red: 1.0 - t * 0.29,
            green: 0.48 - t * 0.28,
            blue: 0.04 + t * 0.16
        )
    }
}
