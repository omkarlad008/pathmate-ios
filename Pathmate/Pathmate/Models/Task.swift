//
//  Task.swift
//  Pathmate
//
//  Created by Omkar Lad on 27/8/2025.
//

// MARK: - Imports
// Foundation is sufficient for these data structures.
import Foundation

// MARK: - ResourceLink

/// **Checklist Task Domain Models**
///
/// Types that describe a user-facing checklist task:
/// - ``ResourceLink``: A labeled external reference (e.g., a guide or tool).
/// - ``TaskDetail``: Explanatory content (what/why/steps/links) for a task.
/// - ``ChecklistTask``: A concrete, actionable item that belongs to a stage.
///
/// These models back the Checklist and Task Detail screens in the prototype.
/// They are value types, `Codable` for persistence, and `Hashable` for lists.
///
/// - SeeAlso: ``Stage``, ``StageID``
/// - Important: Keep user-visible strings short and scannable for compact widths.
/// A labeled external reference associated with a task.
///
/// Use for guides, official resources, or tools relevant to completing a task.
/// `ResourceLink` is `Identifiable` for convenient use in SwiftUI lists.
///
/// - Note: The `id` is generated on creation and is not stable across app launches.
struct ResourceLink: Identifiable, Hashable, Codable {
    /// Random identifier used for SwiftUI list identity..
    var id = UUID()
    /// Short, user-facing label for the link (e.g., “Skyscanner Month View”).
    let label: String
    /// Absolute URL string (e.g., `https://example.com`).
    ///
    /// - Important: Stored as `String`.
    ///   Consider migrating to `URL` to gain validation and type safety.
    let url: String
}

// MARK: - TaskDetail

/// Detailed guidance for completing a checklist task.
///
/// Includes a concise explanation of *what* the task is, *why* it matters,
/// a short list of steps, and optional helpful links.
/// - SeeAlso: ``ChecklistTask``
struct TaskDetail: Hashable, Codable {
    /// A brief description of the task itself (e.g., “Estimate tuition, rent ...”).
    let what: String
    /// Rationale that motivates the task (benefit or risk reduction).
    let why: String
    /// 3–5 concise, sequential steps the user can follow.
    let steps: [String]
    /// Optional references to official guidance or tools.
    let links: [ResourceLink]
}

// MARK: - ChecklistTask

/// An actionable checklist item belonging to a specific journey stage.
///
/// Each task has a stable ``ChecklistTask/key`` used for identity, a title,
/// a subtitle for context, and a ``TaskDetail`` describing how to complete it.
///
/// - Important: Treat ``ChecklistTask/key`` as a stable identifier. Avoid
///   changing it after release to preserve deep-links and stored state.
/// - SeeAlso: ``TaskDetail``, ``ResourceLink``, ``StageID``
///
/// ### Example
/// ```swift
/// let task = ChecklistTask(
///   key: "pre.budget.fx",
///   title: "Budget INR ↔ AUD",
///   subtitle: "Know fees & living costs",
///   detail: TaskDetail(
///     what: "Estimate tuition, rent and monthly expenses in AUD and INR.",
///     why: "Prevents shortfalls and helps choose the right money transfer.",
///     steps: ["List expenses", "Convert totals", "Plan allowance"],
///     links: []
///   )
/// )
/// ```
struct ChecklistTask: Identifiable, Hashable, Codable {
    /// Stable, namespaced identifier (e.g., `"pre.flight.window"`).
    let key: String
    /// Primary, user-facing title of the task.
    let title: String
    /// Secondary context text shown in lists.
    let subtitle: String
    /// Expanded guidance and helpful links for this task.
    let detail: TaskDetail
    /// `Identifiable` conformance using the stable ``ChecklistTask/key``.
    var id: String { key }
}
