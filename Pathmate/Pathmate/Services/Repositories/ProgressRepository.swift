//
//  ProgressRepository.swift
//  Pathmate
//
//  Created by Omkar Lad on 14/10/2025.
//

// MARK: - Imports
// SwiftData for local persistence; Foundation for basic types.
import Foundation
import SwiftData

/// **ProgressRepository (SwiftData)**
///
/// Minimal façade over ``TaskStateEntity`` for completion state:
/// - Answers "is this task done?"
/// - Marks tasks done/undone (maintains `doneAt`)
/// - Computes per-stage progress from static tasks
///
/// - SeeAlso: ``TaskStateEntity``, ``TaskRepository``, ``StageID``
@MainActor
struct ProgressRepository {

    // MARK: - Dependencies
    /// SwiftData context injected from the environment.
    let context: ModelContext

    // MARK: - Queries

    /// Returns `true` if the given task has been completed by the user.
    ///
    /// - Parameter taskKey: Stable identifier (e.g., `"pre.flight.window"`).
    func isDone(_ taskKey: String) -> Bool {
        fetch(taskKey)?.isDone == true
    }

    /// Returns a `0.0 ... 1.0` fraction for the given stage’s tasks.
    ///
    /// - Parameters:
    ///   - stageID: The stage to evaluate.
    ///   - tasks: Static tasks from `TaskRepository.tasks(for:)`.
    func progress(for stageID: StageID, tasks: [ChecklistTask]) -> Double {
        guard !tasks.isEmpty else { return 0 }
        let done = tasks.filter { isDone($0.id) }.count
        return Double(done) / Double(tasks.count)
    }

    // MARK: - Mutations

    /// Marks the task as completed, setting `doneAt = now`.
    ///
    /// - Parameter taskKey: Stable task identifier.
    func markDone(_ taskKey: String) {
        let entity = upsert(taskKey: taskKey, stageRaw: inferStageRaw(taskKey) ?? "")
        entity.isDone = true
        entity.doneAt = Date()
        entity.updatedAt = Date()
        try? context.save()
        WidgetPublisher.publishFromSwiftData(context: context)
    }

    /// Marks the task as not completed, clearing `doneAt`.
    ///
    /// - Parameter taskKey: Stable task identifier.
    func markUndone(_ taskKey: String) {
        guard let entity = fetch(taskKey) else { return }
        entity.isDone = false
        entity.doneAt = nil
        entity.updatedAt = Date()
        try? context.save()
        WidgetPublisher.publishFromSwiftData(context: context)
    }

    // MARK: - Private helpers

    /// Loads an existing `TaskStateEntity` for a given key.
    private func fetch(_ taskKey: String) -> TaskStateEntity? {
        let d = FetchDescriptor<TaskStateEntity>(predicate: #Predicate { $0.taskKey == taskKey })
        return (try? context.fetch(d))?.first
    }

    /// Ensures a `TaskStateEntity` exists for the key; creates if absent.
    private func upsert(taskKey: String, stageRaw: String) -> TaskStateEntity {
        if let existing = fetch(taskKey) { return existing }
        let created = TaskStateEntity(taskKey: taskKey, stageRaw: stageRaw)
        context.insert(created)
        return created
    }

    /// Attempts to infer the owning stage from the static repository.
    ///
    /// - Returns: Raw stage string (or `nil` if not found).
    private func inferStageRaw(_ taskKey: String) -> String? {
        for sid in StageID.allCases {
            if TaskRepository.tasks(for: sid).contains(where: { $0.key == taskKey }) {
                return sid.rawValue
            }
        }
        return nil
    }
}
