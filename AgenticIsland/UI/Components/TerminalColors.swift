//
//  TerminalColors.swift
//  AgenticIsland
//
//  Claude design system – warm palette adapted for dark notch overlay
//

import SwiftUI

struct TerminalColors {
    // MARK: - Brand
    static let prompt = Color(hex: 0xC96442)       // Terracotta Brand – primary accent
    static let coral = Color(hex: 0xD97757)         // Coral Accent – lighter warm variant

    // MARK: - Status
    static let green = Color(red: 0.45, green: 0.72, blue: 0.42)   // Warm green (success)
    static let amber = coral                                         // Approval/warning uses coral
    static let red = Color(hex: 0xB53333)                            // Error Crimson
    static let cyan = coral                                          // Processing uses coral
    static let blue = Color(hex: 0x3898EC)                           // Focus Blue (only cool color)
    static let magenta = Color(red: 0.75, green: 0.45, blue: 0.65)  // Muted warm magenta

    // MARK: - Surfaces
    static let nearBlack = Color(hex: 0x141413)     // Warm near-black – content bg
    static let surface = Color(hex: 0x30302E)       // Dark Surface – cards, elevated
    static let borderDark = Color(hex: 0x30302E)    // Border on dark surfaces

    // MARK: - Text
    static let ivory = Color(hex: 0xFAF9F5)         // Primary text on dark
    static let warmSilver = Color(hex: 0xB0AEA5)    // Secondary text
    static let stoneGray = Color(hex: 0x87867F)      // Tertiary/muted text
    static let charcoalWarm = Color(hex: 0x4D4C48)  // Text on light surfaces

    // MARK: - Legacy aliases
    static let dim = warmSilver
    static let dimmer = stoneGray
    static let background = surface.opacity(0.4)
    static let backgroundHover = surface.opacity(0.6)
}

// MARK: - Hex Color Initializer

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
