//
//  TimelinePlannerAdapter.swift
//  Pathmate
//
//  Created by Omkar Lad on 16/10/2025.
//

import SwiftUI
import SwiftData

@MainActor
struct TimelinePlannerAdapter {
    let context: ModelContext

    func scheduledItems(in interval: DateInterval) -> [TimelineTaskItem] {
        let repo = PlannerRepository(context: context)
        let rows = repo.scheduled()   // existing fetch of scheduled items
        return rows.compactMap { row in
            guard
                !row.isDone,
                let sid  = StageID(rawValue: row.stageRaw),
                let due  = row.dueDate,
                interval.contains(due),
                let stage = sampleStages.first(where: { $0.id == sid }),
                let task  = TaskRepository.tasks(for: sid).first(where: { $0.key == row.taskKey })
            else { return nil }

            return TimelineTaskItem(
                id: row.taskKey,
                title: task.title,
                stageID: sid,
                scheduled: due,
                duration: 60 * 60,
                isDone: row.isDone,
                tint: stage.tint
            )
        }
    }

    // Simple pass-throughs
    func reschedule(taskKey: String, to newDate: Date) {
        PlannerRepository(context: context).updateDate(taskKey: taskKey, to: newDate)
    }

    func markDone(_ taskKey: String) {
        PlannerRepository(context: context).toggleDone(taskKey: taskKey)
    }

    func snooze(_ taskKey: String, by comps: DateComponents) {
        let repo = PlannerRepository(context: context)
        guard
            let current = repo.item(for: taskKey)?.dueDate,
            let newDate = Calendar.current.date(byAdding: comps, to: current)
        else { return }
        repo.updateDate(taskKey: taskKey, to: newDate)
    }
}
