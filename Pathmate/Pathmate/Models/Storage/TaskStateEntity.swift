//
//  TaskStateEntity.swift
//  Pathmate
//
//  Created by Omkar Lad on 14/10/2025.
//

// MARK: - Imports
// SwiftData for local persistence; Foundation for basic types.
import Foundation
import SwiftData

/// **TaskStateEntity (SwiftData)**
///
/// Single source of truth for a user’s interaction with a checklist task.
/// - Unifies “Planner” (via `dueDate`) and “Done” (via `isDone/doneAt`)
/// - Uses your stable `ChecklistTask.key` as `taskKey`
@Model
final class TaskStateEntity {
    // MARK: - Identity & Timestamps
    /// Stable key from static task repo, e.g., "pre.flight.window"
    /// Conceptually unique per user; kept one row per taskKey.
    var taskKey: String
    /// Stage namespace stored as raw string (e.g., "pre", "arr", "uni", "work", "life")
    var stageRaw: String

    var createdAt: Date
    var updatedAt: Date

    // MARK: - Planner state
    /// When set, the task appears under "Scheduled".
    var dueDate: Date?

    // MARK: - Completion state
    /// When true, the task appears under "Completed".
    var isDone: Bool
    /// Timestamp when task was marked done (used for sorting/display).
    var doneAt: Date?

    var note: String?

    // MARK: - Init
    init(
        taskKey: String,
        stageRaw: String,
        dueDate: Date? = nil,
        isDone: Bool = false,
        doneAt: Date? = nil,
        note: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.taskKey = taskKey
        self.stageRaw = stageRaw
        self.dueDate = dueDate
        self.isDone = isDone
        self.doneAt = doneAt
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
