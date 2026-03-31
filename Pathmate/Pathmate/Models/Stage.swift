//
//  Stage.swift
//  Pathmate
//
//  Created by Omkar Lad on 27/8/2025.
//

// MARK: - Imports
// SwiftUI is required for the `Color` mapping in `Tint`.
import SwiftUI

// MARK: - Stage Identity

/// **Stage Models & Palette Tokens**
///
/// Core data types that describe the student journey stages and a small
/// color token system used to render consistent tints across the app.
/// Types here are shared by Home, Journey, Checklist, and Task Detail.
///
/// - SeeAlso: <doc:DataModel>, <doc:Architecture>
/// Stable identifiers for the journey stages.
///
/// Raw values are persisted/serialized (e.g., `UserDefaults` or files) and are
/// also used as list identities in views. Keep these stable across versions.
///
/// Cases:
/// - `preDeparture`: Tasks before leaving the home country.
/// - `arrival`: First week after landing.
/// - `university`: Orientation, ID, systems setup.
/// - `workCompliance`: Jobs, TFN, Fair Work rules.
/// - `lifeBalance`: Groceries, transport, wellbeing.
///
/// Conforms to `CaseIterable`, `Identifiable`, `Codable`, `Hashable` for use in
/// UI lists, persistence, and testing.
enum StageID: String, CaseIterable, Identifiable, Codable, Hashable {
    case preDeparture, arrival, university, workCompliance, lifeBalance
    /// `Identifiable` conformance using the raw string as the stable ID.
    ///
    /// - Important: Changing raw values will break persisted identifiers.
    var id: String { rawValue }
}

// MARK: - Brand Tint Tokens

/// Brand tint tokens decoupled from concrete colors.
///
/// The raw value is encoded with models; views resolve the display color via
/// ``Tint/color``. This keeps the data layer UI-framework-agnostic.
enum Tint: String, Codable {
    case blue, purple, indigo, orange, green
    /// Maps the tint token to a SwiftUI `Color`.
    ///
    /// - Note: Prefer using the token (`Tint`) in your models and call `tint.color`
    ///   in views. This keeps business data independent of UI concerns.
    /// - Returns: The system `Color` associated with the token.
    var color: Color {
        switch self {
        case .blue:   return .blue
        case .purple: return .purple
        case .indigo: return .indigo
        case .orange: return .orange
        case .green:  return .green
        }
    }
}

// MARK: - Stage Model

/// A unit of the student's journey shown as a card and list row.
///
/// Represents a phase like Pre-departure or Arrival with display metadata.
/// Used by Home, Journey, and Checklist screens.
///
/// - Important: ``Stage/progress`` must be in the `0.0...1.0` range.
/// - SeeAlso: ``StageID``, ``Tint``
///
/// ### Example
/// ```swift
/// let stage = Stage(id: .arrival,
///                   title: "Arrival",
///                   subtitle: "First week after landing",
///                   symbol: "mappin.and.ellipse",
///                   tint: .purple,
///                   progress: 0.2)
/// ```
struct Stage: Identifiable, Hashable, Codable {
    /// Stable identity of the stage (used for persistence and list identity).
    let id: StageID
    /// Display title, e.g., “Pre-departure”.
    let title: String
    /// Short descriptive subtitle shown as the secondary label in lists.
    let subtitle: String
    /// SF Symbols name for the stage icon (e.g., `"airplane"`).
    let symbol: String
    /// Brand tint token; resolve to a concrete color via ``Tint/color`` in views.
    let tint: Tint
    /// Completion fraction for this stage in the range `0.0...1.0`.
    var progress: Double
}

// MARK: - Display title for StageID (used by widget)
extension StageID {
    var displayTitle: String {
        switch self {
        case .preDeparture:   return "Pre-departure"
        case .arrival:        return "Arrival"
        case .university:     return "University"
        case .workCompliance: return "Work & Compliance"
        case .lifeBalance:    return "Life & Balance"
        }
    }
}
