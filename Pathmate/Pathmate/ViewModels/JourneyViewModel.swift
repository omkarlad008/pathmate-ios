//
//  JourneyViewModel.swift
//  Pathmate
//
//  Created by Omkar Lad on 9/10/2025.
//

import Foundation
import Combine

/// **JourneyViewModel**
///
/// Publishes the ordered list of journey stages shown in `JourneyView`.
/// - SeeAlso: ``JourneyView``
final class JourneyViewModel: ObservableObject {
    /// Stages shown in the Journey screen, preserved in UI display order.
    ///
    /// - Important: Consumers should not resort or mutate this array directly.
    @Published private(set) var stages: [Stage] = []

    /// Data access abstraction (kept for symmetry / future needs).
    private let taskService: TaskService

    /// Creates a view model with an injected task service (kept for symmetry).
    /// - Parameter taskService: Service dependency.
    init(taskService: TaskService = StaticTaskService()) {
        self.taskService = taskService
        self.stages = sampleStages
    }
    
    /// Return the checklist tasks for a given stage
    func tasks(for stageID: StageID) -> [ChecklistTask] {
        return TaskRepository.tasks(for: stageID)
    }
}
