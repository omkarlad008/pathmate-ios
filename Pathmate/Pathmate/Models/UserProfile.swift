//
//  UserProfile.swift
//  Pathmate
//
//  Created by Kshitija on 28/8/2025.
//

// MARK: - Imports
// Foundation is sufficient for models and Date/DateFormatter handling.
import Foundation

// **User Profile & Study Level Models**
// Types captured on the Setup page: full name, route (from→to), study level,
// intake month–year, and campus. Codable for persistence; Equatable for UI diffs.

// MARK: - Study Level

/// Student study level options used in Setup and Profile.
///
/// The `rawValue` is user-visible (e.g., “Bachelor”, “Master”), so changing it
/// affects displayed strings. Prefer localisation in later iterations.
/// - SeeAlso: ``UserProfile``
enum StudyLevel: String, CaseIterable, Identifiable, Codable {
    case bachelor = "Bachelor"
    case master   = "Master"
    /// `Identifiable` conformance backed by the `rawValue`.
    ///
    /// - Important: Keep raw values stable to avoid breaking stored IDs.
    var id: String { rawValue }
}

// MARK: - User Profile

/// Minimal user profile captured during onboarding (Setup).
///
/// Includes identity, route (from→to), study level, intake date, and campus.
/// Defaults serve as v1 presets to streamline onboarding.
///
/// - Note: Conforms to `Codable` for persistence and `Equatable` for simple UI diffs.
/// - SeeAlso: ``StudyLevel``, ``monthYearFormatter``
struct UserProfile: Codable, Equatable {
    /// Full legal name as entered by the student.
    var fullName: String = ""
    /// Country of origin (v1 preset: “India”).
    var fromCountry: String = "India"       // v1 preset
    /// Destination country (v1 preset: “Australia”).
    var toCountry:   String = "Australia"   // v1 preset
    /// Declared study level. Defaults to ``StudyLevel/bachelor`` for v1.
    var studyLevel: StudyLevel = .bachelor
    /// Intended intake month (stored as a `Date`, displayed as Month–Year).
    ///
    /// - Important: Only the month/year is shown in UI; day components are ignored.
    var intakeDate: Date = .init()
    /// Target city/campus (e.g., “Melbourne City”).
    var cityCampus: String = ""
}

/// Formats dates as Month–Year (e.g., “Oct 2025”) for intake display.
///
/// Uses the device locale/time zone by default.
/// - Note: For full localization later, prefer:
///   `formatter.setLocalizedDateFormatFromTemplate("MMMyyyy")`.
///
/// ### Example
/// ```swift
/// let text = monthYearFormatter.string(from: profile.intakeDate)
/// // "Oct 2025"
/// ```
let monthYearFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMM yyyy"
    return f
}()
