//
//  StageRow.swift
//  Pathmate
//
//  Created by Omkar Lad on 27/8/2025.
//

// MARK: - Imports
// SwiftUI for view composition and system colors/typography.
import SwiftUI

/// **StageRow**
///
/// A compact row view that displays a journey stage with icon tile, title,
/// subtitle, and a progress bar. Used in the Stages/Journey list and anywhere
/// a stage summary is needed.
///
/// Layout: 64×64 tinted icon tile on the left, stacked text and progress on the right.
/// The trailing edge shows an integer percentage derived from the `progress` fraction.
///
/// - Important: ``StageRow/progress``.
/// - SeeAlso: ``Stage``, ``StageID``, ``JourneyView`
///
/// ### Example
/// ```swift
/// StageRow(icon: "airplane", tint: .blue,
///          title: "Pre-departure",
///          subtitle: "Tasks before leaving India",
///          progress: 0.6)
/// ```
struct StageRow: View {
    /// SF Symbols name for the tile icon (e.g., `"airplane"`).
    let icon: String
    /// Brand tint color applied to the icon and progress bar.
    let tint: Color
    /// Primary label shown with `.headline` typography.
    let title: String
    /// Secondary label in `.subheadline`, single-line truncated.
    let subtitle: String
    /// Completion fraction (`0.0...1.0`) displayed as a bar and integer percent.
    let progress: Double

    /// View content: leading icon tile + trailing text stack with progress.
    ///
    /// - Note: Percentage uses `monospacedDigit()` to avoid layout shift when animating.
    /// - Important: Keep text brief for compact widths to prevent truncation.
    var body: some View {
        // Container: icon tile (left) + textual content (right).
        HStack(alignment: .top, spacing: 16) {
            // Icon tile: rounded rectangle background tinted at low opacity + SF Symbol.
            ZStack {
                // Soft-corner tile background for visual grouping and brand presence.
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.15))
                // Stage symbol with fixed size/weight; color comes from `tint`.
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
            }
            // Fixed tile footprint to keep rows aligned in a scrolling list.
            .frame(width: 64, height: 64)

            // Textual content: title row (with trailing percent), subtitle, and progress bar.
            VStack(alignment: .leading, spacing: 6) {
                // Title row with trailing percentage for quick scanning.
                HStack {
                    // Primary label; avoid multiline to maintain compact row height.
                    Text(title).font(.headline)
                    Spacer()
                    // Integer percentage derived from fractional progress; secondary styling.
                    Text("\(Int(progress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                // Context subtitle; single-line with secondary color for hierarchy.
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                // Progress bar tinted to match the icon tile color.
                ProgressView(value: progress)
                    .tint(tint)
                    // Touch-friendly vertical padding; helps with list row hit targets (HIG).
                    .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 12)
    }
}

// Design-time preview for rapid iteration during development.
#Preview {
    StageRow(icon: "airplane", tint: .blue,
             title: "Pre-departure",
             subtitle: "Tasks before leaving India",
             progress: 0.6)
    .padding()
}
