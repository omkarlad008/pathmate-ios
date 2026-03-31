//
//  TaskService.swift
//  Pathmate
//
//  Created by Omkar Lad on 9/10/2025.
//

import Foundation

/// **TaskService**
///
/// Abstraction for retrieving checklist tasks for a given stage.
/// Keeps data access out of views and view models for easy swapping
/// - SeeAlso: ``StageID``, ``ChecklistTask``, ``StaticTaskService```
///
/// ### Example
/// ```swift
/// let service: TaskService = StaticTaskService()
/// let tasks = service.tasks(for: .arrival)
/// ```
protocol TaskService {
    /// Returns checklist tasks for a specific journey stage.
    /// - Parameter stage: The stage whose tasks should be fetched.
    func tasks(for stage: StageID) -> [ChecklistTask]
}

/// **StaticTaskService**
///
/// Simple implementation backed by the existing `TaskRepository`
/// - SeeAlso: ``TaskRepository```
/// - Note: Synchronous, in-memory placeholder; swap for SwiftData/Firestore in A2.
struct StaticTaskService: TaskService {
    func tasks(for stage: StageID) -> [ChecklistTask] {
        TaskRepository.tasks(for: stage)
    }
}
