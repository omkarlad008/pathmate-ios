//
//  ChecklistView.swift
//  Pathmate
//
//  Created by Omkar Lad on 27/8/2025.
//

// MARK: - Imports
// SwiftUI for list, navigation, and styling primitives.
// SwiftData for local persistence of task state (done / dueDate).
import SwiftUI
import SwiftData

/// **ChecklistView**
///
/// Shows the actionable checklist items for a given ``Stage``. Each row
/// navigates to ``TaskDetailView`` for concise guidance (what/why/steps/links).
/// Tasks are provided by the static repository,,
/// while **state** (done / scheduled) is persisted in **SwiftData**.
///
/// - Important: Row checkmarks and swipe actions are SwiftData-backed via
///   ``TaskStateEntity`` accessed through lightweight repositories.
/// - SeeAlso: ``TaskDetailView``, ``TaskStateEntity``, ``PlannerRepository``
struct ChecklistView: View {
    /// The stage whose tasks we’re listing (e.g., Pre-departure, Arrival).
    let stage: Stage

    // SwiftData model context for reads/writes.
    @Environment(\.modelContext) private var modelContext

    @EnvironmentObject private var auth: AuthService
    
    // Observe task states so checkmarks update live on toggle.
    @Query private var taskStates: [TaskStateEntity]

    // Derived task list from the static repository (stable for A2).
    private var tasks: [ChecklistTask] {
        TaskRepository.tasks(for: stage.id)
    }

    var body: some View {
        // Reactivity anchor (keeps checkmarks in sync)
        let _ = taskStates

        List {
            Section {
                ForEach(tasks, id: \.key) { task in
                    NavigationLink {
                        TaskDetailView(item: task)
                    } label: {
                        ChecklistRowSD(task: task, stageID: stage.id)
                            .environment(\.modelContext, modelContext)
                    }
                    // Swipe-to-done/undone using SwiftData
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        let repo = PlannerRepository(context: modelContext)
                        let isDone = (repo.item(for: task.key)?.isDone ?? false)

                        if isDone {
                            Button {
                                withAnimation { repo.toggleDone(taskKey: task.key) } // mark as undone
                                if let uid = auth.uid {
                                    Task { await FirestoreTaskStateService.shared.push(uid: uid, taskKey: task.key, modelContext: modelContext) }
                                }
                            } label: {
                                Label("Mark undone", systemImage: "arrow.uturn.backward.circle")
                            }
                            .tint(.orange)
                        } else {
                            Button {
                                // If never scheduled, ensure a row exists and complete it
                                withAnimation { repo.ensureAndComplete(task: task, stageID: stage.id) }
                                if let uid = auth.uid {
                                    Task { await FirestoreTaskStateService.shared.push(uid: uid, taskKey: task.key, modelContext: modelContext) }
                                }
                            } label: {
                                Label("Mark done", systemImage: "checkmark.circle.fill")
                            }
                            .tint(.green)
                        }
                    }
                }
            } header: {
                Text(stage.title).textCase(nil)
            }
        }
        // Compact, hierarchical appearance suited to checklists.
        .listStyle(.insetGrouped)
        // Title reflects the current stage (e.g., "Pre-departure").
        .navigationTitle(stage.title)
        // Smooth refresh when @Query publishes changes
        .animation(.default, value: taskStates)
    }
}

// MARK: - Row (SwiftData-backed)

/// **ChecklistRowSD**
///
/// Row displaying a task’s title/subtitle with a leading checkmark
/// that reflects SwiftData state (`TaskStateEntity.isDone`).
/// Tapping the row navigates to ``TaskDetailView`` via the parent `NavigationLink`.
private struct ChecklistRowSD: View {
    @Environment(\.modelContext) private var modelContext
    // Observe changes so the row redraws immediately when state changes elsewhere.
    @Query private var taskStates: [TaskStateEntity]

    let task: ChecklistTask
    let stageID: StageID

    /// Snapshot of the SwiftData state for this task (if present).
    private var state: PlannerRepository.Item? {
        PlannerRepository(context: modelContext).item(for: task.key)
    }

    /// Whether the task has been marked as done.
    private var isDone: Bool { state?.isDone ?? false }

    var body: some View {
        // Reactivity anchor for this specific row
        let _ = taskStates

        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .imageScale(.large)
                .foregroundStyle(isDone ? .green : .secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if !task.subtitle.isEmpty {
                    Text(task.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            // Optional small hint if scheduled
            if let due = state?.dueDate {
                Text(shortDateLabel(due))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    // MARK: - Helpers
    private func shortDateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.abbreviated).day())
    }
}
