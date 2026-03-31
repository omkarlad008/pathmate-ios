//
//  WidgetPublisher.swift
//  Pathmate
//

import Foundation
import SwiftData
import WidgetKit

/// Publishes a compact, widget-friendly snapshot of planner state into the shared
/// App Group for the Pathmate widget.
///
/// This utility reads ``TaskStateEntity`` rows from SwiftData, derives:
/// - a *horizon* progress ring (overdue −2 days → next 7 days),
/// - the **next three** upcoming tasks, and
/// - the *overall* static checklist progress (based on ``TaskRepository``),
/// then writes a ``WidgetSnapshot`` via ``WidgetBridge`` and triggers
/// `WidgetCenter.reloadTimelines(ofKind:)` when data actually changes.
///
/// Usage:
/// ```swift
/// @Environment(\.modelContext) var context
/// // Call after onboarding and after any task/planner mutation
/// WidgetPublisher.publishFromSwiftData(context: context)
/// ```
///
/// - Important: Times are computed in **Australia/Melbourne** (ISO-8601 calendar) to
///   match the app’s primary locale.
/// - SeeAlso: ``WidgetSnapshot``, ``WidgetTask``, ``WidgetBridge``, ``WidgetKind``,
///   ``TaskStateEntity``, ``TaskRepository``, ``StageID``.
enum WidgetPublisher {

    /// Build and publish the current widget snapshot derived from SwiftData.
    ///
    /// The snapshot includes:
    /// - `next`: up to **3** not-done tasks scheduled within the *horizon* (−2d…+7d)
    ///   sorted by `dueDate` ascending; falls back to the earliest scheduled tasks if the
    ///   horizon is empty.
    /// - `todayScheduled` / `todayDone`: counts over the *same horizon window* (−2d…+7d),
    ///   used for the ring’s numerator/denominator.
    /// - `overallTotal` / `overallDone`: progress across **all static checklist tasks**
    ///   from ``TaskRepository`` (filters SwiftData states to known `taskKey`s).
    ///
    /// - Parameter context: The SwiftData `ModelContext` to query.
    /// - Note: The writer performs a change check (`WidgetBridge.read() != snap`) to avoid
    ///   unnecessary timeline reloads and reduce widget churn.
    /// - Important: Ensure you call this after **every** state mutation that affects planner
    ///   or completion status (e.g., swipe on Checklist, Home tile toggle, Planner actions,
    ///   widget App Intent).
    static func publishFromSwiftData(context: ModelContext) {
        // Melbourne time, ISO weeks
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "Australia/Melbourne") ?? .current

        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        let todayEnd   = cal.date(byAdding: .day, value: 1, to: todayStart)!

        // Horizon: include a little overdue + the next week
        let horizonStart = cal.date(byAdding: .day, value: -2, to: todayStart)! // catch “yesterday”
        let horizonEnd   = cal.date(byAdding: .day, value: 7,  to: todayStart)! // next 7 days

        // Shadow locals help the type-checker inside #Predicate
        let hs = horizonStart, he = horizonEnd
        let _ = todayStart,  _ = todayEnd

        // NEXT (top 3, earliest-first, within horizon, not done)
        var nextFetch = FetchDescriptor<TaskStateEntity>(
            predicate: #Predicate { e in
                e.isDone == false &&
                e.dueDate != nil &&
                e.dueDate! >= hs &&
                e.dueDate! <  he
            },
            sortBy: [SortDescriptor(\.dueDate, order: .forward)]
        )
        nextFetch.fetchLimit = 3
        var nextEntities: [TaskStateEntity] = (try? context.fetch(nextFetch)) ?? []

        // Fallback: soonest scheduled (any date, not done)
        if nextEntities.isEmpty {
            var anyUpcoming = FetchDescriptor<TaskStateEntity>(
                predicate: #Predicate { e in e.isDone == false && e.dueDate != nil },
                sortBy: [SortDescriptor(\.dueDate, order: .forward)]
            )
            anyUpcoming.fetchLimit = 3
            nextEntities = (try? context.fetch(anyUpcoming)) ?? []
        }

        // HORIZON progress (scheduled vs done inside horizon window)
        let scheduledToday = (try? context.fetch(
            FetchDescriptor<TaskStateEntity>(
                predicate: #Predicate { e in
                    e.dueDate != nil && e.dueDate! >= hs && e.dueDate! < he
                }
            )
        ).count) ?? 0

        let doneToday = (try? context.fetch(
            FetchDescriptor<TaskStateEntity>(
                predicate: #Predicate { e in
                    e.isDone == true && e.dueDate != nil && e.dueDate! >= hs && e.dueDate! < he
                }
            )
        ).count) ?? 0
        
        // OVERALL progress (done out of ALL static checklist tasks)
        let allStaticTasks = StageID.allCases.flatMap { TaskRepository.tasks(for: $0) }
        let overallTotal   = allStaticTasks.count
        let staticKeys     = Set(allStaticTasks.map(\.key))
        let overallDone    = ((try? context.fetch(
            FetchDescriptor<TaskStateEntity>(predicate: #Predicate { $0.isDone == true })
        )) ?? []).filter { staticKeys.contains($0.taskKey) }.count

        // Map to lightweight widget models
        let next: [WidgetTask] = nextEntities.compactMap { e in
            guard let due = e.dueDate else { return nil }
            let info = TaskRepository.titleAndStage(for: e.taskKey)   // uses your static repo
            return WidgetTask(
                id: e.taskKey,
                title: info.title,
                scheduledDate: due,
                isDone: e.isDone,
                stageName: info.stage
            )
        }

        let snap = WidgetSnapshot(
            next: next,
            todayScheduled: scheduledToday,
            todayDone: doneToday,
            overallTotal: overallTotal,
            overallDone: overallDone
        )
        if WidgetBridge.read() != snap {
            WidgetBridge.write(snap)
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.pathmate)
        }
    }
}
