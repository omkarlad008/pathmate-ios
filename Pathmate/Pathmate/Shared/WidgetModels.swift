//
//  WidgetModels.swift
//  Pathmate
//
//  Created by Omkar Lad on 15/10/2025.
//

import Foundation
/// A lightweight task row model optimized for widget rendering.
///
/// - Important: Keep fields minimal to reduce encode/decode overhead.
/// - SeeAlso: ``WidgetSnapshot``
public struct WidgetTask: Codable, Identifiable, Hashable {
    /// Unique identifier (matches the app’s `taskKey`).
    public let id: String
    /// Short user-facing title for display in the widget list.
    public let title: String
    /// Due date used for sorting and for horizon computations.
    public let scheduledDate: Date
    /// Current completion flag (mirrors SwiftData state).
    public let isDone: Bool
    /// Optional stage display name (e.g., “Arrival”), if available.
    public let stageName: String?
}
/// The complete widget payload written through the App Group bridge.
///
/// Contains the **top three** upcoming tasks, ring numerators/denominators for
/// the horizon window (−2 days … +7 days), and overall completion totals.
public struct WidgetSnapshot: Codable, Hashable {
    /// Earliest-first list of the next three tasks to show in the widget.
    public var next: [WidgetTask]
    /// Count of tasks due within the horizon window (ring denominator).
    public var todayScheduled: Int
    /// Count of tasks done within the horizon window (ring numerator).
    public var todayDone: Int
    /// Total number of static checklist tasks (across all stages).
    public var overallTotal: Int
    /// Number of tasks completed overall (across all stages).
    public var overallDone: Int
    /// An empty snapshot used to initialize or recover widget state quickly.
    public static var empty: Self {
        .init(next: [], todayScheduled: 0, todayDone: 0, overallTotal: 0, overallDone: 0)
    }
}
