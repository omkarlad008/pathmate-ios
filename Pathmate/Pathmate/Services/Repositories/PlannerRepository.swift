//
//  PlannerRepository.swift
//  Pathmate
//
//  Created by Omkar Lad on 14/10/2025.
//

// MARK: - Imports
// SwiftData for local persistence; Foundation for date/sorting.
import Foundation
import SwiftData

/// **PlannerRepository (SwiftData)**
///
/// Unifies "Planner" and "Completed" views over ``TaskStateEntity``:
/// - `dueDate`   → Scheduled tab
/// - `isDone`    → Completed tab (sorted by `doneAt` desc)
///
/// - Important: Uses the *same* `TaskStateEntity` as progress to keep state
///   consistent across Planner, Home, Checklist, and Task Detail.
/// - SeeAlso: ``TaskStateEntity``, ``ChecklistTask``, ``StageID``
@MainActor
struct PlannerRepository {

    // MARK: - Dependencies
    /// SwiftData context injected from the environment.
    let context: ModelContext

    // MARK: - Read models (lightweight DTO for UI consumption)
    struct Item: Identifiable, Hashable {
        public var id: String { taskKey }
        let taskKey: String
        let stageRaw: String
        let dueDate: Date?
        let isDone: Bool
        let doneAt: Date?
        let updatedAt: Date
    }

    // MARK: - Queries

    /// All scheduled items (`dueDate != nil`, `isDone == false`) sorted by date.
    func scheduled() -> [Item] {
        let d = FetchDescriptor<TaskStateEntity>(
            predicate: #Predicate { $0.dueDate != nil && $0.isDone == false },
            sortBy: [SortDescriptor(\.dueDate, order: .forward)]
        )
        let rows = (try? context.fetch(d)) ?? []
        return rows.map(toItem)
    }

    /// All completed items (`isDone == true`) sorted by `doneAt` desc (fallback to `updatedAt`).
    func completed() -> [Item] {
        let d = FetchDescriptor<TaskStateEntity>(
            predicate: #Predicate { $0.isDone == true },
            sortBy: [
                SortDescriptor(\.doneAt, order: .reverse),
                SortDescriptor(\.updatedAt, order: .reverse)
            ]
        )
        let rows = (try? context.fetch(d)) ?? []
        return rows.map(toItem)
    }

    /// Returns `true` if a task has any planner state row.
    func isInPlanner(taskKey: String) -> Bool {
        fetchRow(taskKey) != nil
    }

    /// Returns the planner snapshot for a given task, if present.
    func item(for taskKey: String) -> Item? {
        fetchRow(taskKey).map(toItem)
    }

    // MARK: - Mutations

    /// Adds (or updates) a planner entry for a task with a due date.
    ///
    /// - Parameters:
    ///   - task: Static task descriptor.
    ///   - stageID: Owner stage (used to namespace the entity).
    ///   - dueDate: Target date to schedule.
    func add(task: ChecklistTask, stageID: StageID, dueDate: Date?) {
        let e = upsert(taskKey: task.key, stageRaw: stageID.rawValue)
        e.stageRaw  = stageID.rawValue
        e.dueDate   = dueDate
        e.isDone    = false
        e.doneAt    = nil
        e.updatedAt = Date()
        try? context.save()
        WidgetPublisher.publishFromSwiftData(context: context)
    }

    /// Removes the date (keeps the row for history/consistency).
    func remove(taskKey: String) {
        guard let e = fetchRow(taskKey) else { return }
        e.dueDate   = nil
        e.updatedAt = Date()
        try? context.save()
        WidgetPublisher.publishFromSwiftData(context: context)
    }

    /// Changes the scheduled date.
    func updateDate(taskKey: String, to newDate: Date) {
        let e = upsert(taskKey: taskKey, stageRaw: inferStageRaw(taskKey) ?? "")
        e.dueDate   = newDate
        e.updatedAt = Date()
        try? context.save()
        WidgetPublisher.publishFromSwiftData(context: context)
    }

    /// Toggles completion; maintains `doneAt` semantics.
    func toggleDone(taskKey: String) {
        let e = upsert(taskKey: taskKey, stageRaw: inferStageRaw(taskKey) ?? "")
        e.isDone.toggle()
        e.doneAt    = e.isDone ? Date() : nil
        e.updatedAt = Date()
        try? context.save()
        WidgetPublisher.publishFromSwiftData(context: context)
    }

    /// Convenience for flows where user hits "Mark as done" before adding.
    func ensureAndComplete(task: ChecklistTask, stageID: StageID, defaultDate: Date = .now) {
        let e = upsert(taskKey: task.key, stageRaw: stageID.rawValue)
        e.stageRaw  = stageID.rawValue
        // Keep an existing due date; otherwise set a default so it appears dated in Completed.
        e.dueDate   = e.dueDate ?? defaultDate
        e.isDone    = true
        e.doneAt    = Date()
        e.updatedAt = Date()
        try? context.save()
        WidgetPublisher.publishFromSwiftData(context: context)
    }

    // MARK: - Private helpers

    private func toItem(_ e: TaskStateEntity) -> Item {
        Item(taskKey: e.taskKey,
             stageRaw: e.stageRaw,
             dueDate: e.dueDate,
             isDone: e.isDone,
             doneAt: e.doneAt,
             updatedAt: e.updatedAt)
    }

    private func fetchRow(_ taskKey: String) -> TaskStateEntity? {
        let d = FetchDescriptor<TaskStateEntity>(predicate: #Predicate { $0.taskKey == taskKey })
        return (try? context.fetch(d))?.first
    }

    private func upsert(taskKey: String, stageRaw: String) -> TaskStateEntity {
        if let existing = fetchRow(taskKey) { return existing }
        let created = TaskStateEntity(taskKey: taskKey, stageRaw: stageRaw)
        context.insert(created)
        return created
    }

    /// Attempts to infer the owning stage from the static repository.
    private func inferStageRaw(_ taskKey: String) -> String? {
        for sid in StageID.allCases {
            if TaskRepository.tasks(for: sid).contains(where: { $0.key == taskKey }) {
                return sid.rawValue
            }
        }
        return nil
    }
}
