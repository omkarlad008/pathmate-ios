/// Widget-facing App Intents for interactive actions (iOS 17+).
///
/// - ``MarkTaskDoneIntent`` toggles a task to *done* and patches the widget snapshot.
/// - ``RescheduleTaskIntent`` updates a task’s due date and re-sorts the widget list.
///
/// Both intents:
/// - operate on a lightweight SwiftData container, and
/// - update the App Group snapshot via ``WidgetBridge`` then call
///   `WidgetCenter.shared.reloadTimelines(ofKind:)`.
import AppIntents
import SwiftData
import WidgetKit

// MARK: - Mark task done (from widget)
/// Marks a task as **done** from the widget and updates the shared snapshot.
///
/// Behavior:
/// - Loads the `TaskStateEntity` from a temporary SwiftData container.
/// - Sets `isDone = true` and `doneAt = .now`.
/// - Patches the current ``WidgetSnapshot`` (removes the task from `next`,
///   bumps `todayDone` only if within the horizon window, and increments
///   `overallDone` if applicable).
/// - Triggers a widget timeline reload.
///
/// - SeeAlso: ``WidgetBridge``, ``WidgetSnapshot``, ``WidgetTask``
struct MarkTaskDoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Task Done"
    /// Runs entirely in the background; does **not** foreground the app.
    static var openAppWhenRun: Bool = false
    /// Hidden from Spotlight/Shortcuts UI; invoked only via the widget.
    static var isDiscoverable: Bool = false

    /// The unique `taskKey` of the checklist task to mark as done.
    @Parameter(title: "Task ID") var taskID: String

    init() {}
    init(taskID: String) { self.taskID = taskID }

    /// Executes the mark-as-done flow, patches the snapshot, and reloads timelines.
    ///
    /// - Returns: An empty `IntentResult` on success.
    /// - Important: Date math uses **Australia/Melbourne** time to evaluate the
    ///   horizon window (−2 days … +7 days) consistently with the widget.
    func perform() async throws -> some IntentResult {
        try await MainActor.run {
            let container = try ModelContainer(for: TaskStateEntity.self)
            let context = ModelContext(container)

            var fetch = FetchDescriptor<TaskStateEntity>(
                predicate: #Predicate { $0.taskKey == taskID }
            )
            fetch.fetchLimit = 1

            if let item = try context.fetch(fetch).first, !item.isDone {
                let wasDue = item.dueDate
                item.isDone = true
                item.doneAt = .now
                try context.save()

                // Patch the current widget snapshot so UI updates instantly
                var snap = WidgetBridge.read() ?? .empty
                // remove this task from "next"
                snap.next.removeAll { $0.id == taskID }

                // increment today's done only if it was due today
                // increment "done" only if due is inside the widget's horizon window
                var cal = Calendar(identifier: .iso8601)
                cal.timeZone = TimeZone(identifier: "Australia/Melbourne") ?? .current
                let base = cal.startOfDay(for: Date())
                let hs = cal.date(byAdding: .day, value: -2, to: base)!
                let he = cal.date(byAdding: .day, value: 7,  to: base)!
                if let due = wasDue, due >= hs && due < he {
                    snap.todayDone = min(snap.todayDone + 1, snap.todayScheduled)
                }
                // Also reflect overall completion for the widget's blue ring
                if snap.overallDone < snap.overallTotal {
                    snap.overallDone += 1
                }
                WidgetBridge.write(snap)
            }
        }

        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.pathmate)
        return .result()
    }
}

// MARK: - (Optional) Reschedule task
/// Reschedules a task’s due date from the widget and resorts the `next` list.
///
struct RescheduleTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Reschedule Task"
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false
    /// The `taskKey` of the checklist task to reschedule.
    @Parameter(title: "Task ID") var taskID: String
    /// The replacement due date written to SwiftData and the snapshot.
    @Parameter(title: "New Date") var newDate: Date
    /// How the intent appears if surfaced (kept non-discoverable for A2).
    static var parameterSummary: some ParameterSummary {
        Summary("Reschedule \(\.$taskID) to \(\.$newDate)")
    }

    init() {}
    init(taskID: String, newDate: Date) { self.taskID = taskID; self.newDate = newDate }

    /// Writes the new due date to SwiftData, patches the snapshot, sorts by date,
    /// limits to the top 3, and reloads the widget timeline.
    func perform() async throws -> some IntentResult {
        try await MainActor.run {
            let container = try ModelContainer(for: TaskStateEntity.self)
            let context = ModelContext(container)

            var fetch = FetchDescriptor<TaskStateEntity>(
                predicate: #Predicate { $0.taskKey == taskID }
            )
            fetch.fetchLimit = 1

            if let item = try context.fetch(fetch).first {
                item.dueDate = newDate
                try context.save()

                // Patch snapshot: update date in next if present and keep order on reload
                var snap = WidgetBridge.read() ?? .empty
                if let idx = snap.next.firstIndex(where: { $0.id == taskID }) {
                    let old = snap.next[idx]
                    let updated = WidgetTask(
                        id: old.id,
                        title: old.title,
                        scheduledDate: newDate,
                        isDone: old.isDone,
                        stageName: old.stageName
                    )
                    snap.next[idx] = updated
                    snap.next.sort { $0.scheduledDate < $1.scheduledDate }
                }
                WidgetBridge.write(snap)
            }
        }

        WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.pathmate)
        return .result()
    }
}
