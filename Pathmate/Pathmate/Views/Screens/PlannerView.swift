//
//  PlannerView.swift
//  Pathmate
//
//  Created by Omkar Lad on 27/8/2025.
//

// MARK: - Imports
import SwiftUI
import SwiftData

/// **PlannerView**
///
/// Planner screen showing tasks the user scheduled or completed.
/// Two tabs:
/// - **Scheduled:** tasks with a due date (not done yet)
/// - **Completed:** tasks marked as done (sorted by completion time)
/// - **Timeline:** shows timeline
///
/// SwiftData via ``PlannerRepository`` ensures persistence across relaunches.
struct PlannerView: View {
    enum Tab: String, CaseIterable { case scheduled = "Scheduled", completed = "Completed", timeline = "Timeline" }

    // SwiftData
    @Environment(\.modelContext) private var modelContext
    
    @EnvironmentObject private var auth: AuthService
    
    // Observe state so the view refreshes when items change
    @Query private var taskStates: [TaskStateEntity]

    @State private var tab: Tab = .scheduled
    @State private var navTask: ChecklistTask?
    @State private var editingSDItem: PlannerRepository.Item?
    
    @StateObject private var timelineUndo = TimelineUndo()
    @State private var showUndoPrompt = false

    private var repo: PlannerRepository { PlannerRepository(context: modelContext) }

    // Extended to be exhaustive; timeline doesn't use this list
    private var items: [PlannerRepository.Item] {
        switch tab {
        case .scheduled: return repo.scheduled()
        case .completed: return repo.completed()
        case .timeline:  return [] // timeline renders via adapter
        }
    }

    var body: some View {
        // Reactivity anchor: recompute `items` whenever TaskStateEntity changes
        let _ = taskStates

        NavigationStack {
            VStack(spacing: 12) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Switch between existing list UI and the new Timeline tab
                Group {
                    switch tab {
                    case .scheduled, .completed:
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(items, id: \.taskKey) { it in
                                    if let stage = StageID(rawValue: it.stageRaw),
                                       let task = TaskRepository.tasks(for: stage).first(where: { $0.key == it.taskKey }) {
                                        PlannerCard(task: task,
                                                    stage: stage,
                                                    dueDate: it.dueDate,
                                                    isCompleted: it.isDone,
                                                    doneAt: it.doneAt)
                                        .onTapGesture { navTask = task }
                                        .contextMenu {
                                            Button {
                                                editingSDItem = it
                                            } label: {
                                                Label("Edit date", systemImage: "calendar.badge.clock")
                                            }
                                            if it.isDone {
                                                Button {
                                                    withAnimation { repo.toggleDone(taskKey: it.taskKey) }
                                                    if let uid = auth.uid {
                                                        Task { await FirestoreTaskStateService.shared.push(uid: uid, taskKey: it.taskKey, modelContext: modelContext) }
                                                    }
                                                } label: { Label("Mark as undone", systemImage: "arrow.uturn.backward") }
                                            } else {
                                                Button {
                                                    withAnimation { repo.toggleDone(taskKey: it.taskKey) }
                                                    if let uid = auth.uid {
                                                        Task { await FirestoreTaskStateService.shared.push(uid: uid, taskKey: it.taskKey, modelContext: modelContext) }
                                                    }
                                                } label: { Label("Mark as done", systemImage: "checkmark.circle") }
                                            }
                                            if !it.isDone {
                                                Button(role: .destructive) {
                                                    withAnimation { repo.remove(taskKey: it.taskKey) }
                                                    if let uid = auth.uid {
                                                        Task { await FirestoreTaskStateService.shared.push(uid: uid, taskKey: it.taskKey, modelContext: modelContext) }
                                                    }
                                                } label: { Label("Remove from planner", systemImage: "trash") }
                                            }
                                        }
                                    }
                                }

                                if items.isEmpty {
                                    Text(tab == .scheduled ? "No scheduled tasks" : "Nothing completed yet")
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 40)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }

                    case .timeline:
                        let adapter = TimelinePlannerAdapter(context: modelContext)
                        let cfg = TimelineConfig()
                        let start = Calendar.current.date(byAdding: .day, value: cfg.startOffsetDays,
                                                          to: Calendar.current.startOfDay(for: Date()))!
                        let end   = Calendar.current.date(byAdding: .day, value: cfg.dayRange, to: start)!
                        let interval = DateInterval(start: start, end: end)

                        ZStack {
                            // Invisible view to capture shakes
                            ShakeDetector().frame(width: 0, height: 0)

                            TimelineCanvasView(
                                items: adapter.scheduledItems(in: interval),
                                config: cfg,
                                onSchedule: { key, newDate in
                                    // capture old state for undo
                                    let repo = PlannerRepository(context: modelContext)
                                    let oldDate = repo.item(for: key)?.dueDate

                                    withAnimation(.spring) { adapter.reschedule(taskKey: key, to: newDate) }
                                    if let uid = auth.uid {
                                        Task { await FirestoreTaskStateService.shared.push(uid: uid, taskKey: key, modelContext: modelContext) }
                                    }

                                    // push undo event
                                    timelineUndo.push(.init(
                                        label: "Rescheduled to \(newDate.formatted(date: .abbreviated, time: .shortened))",
                                        undo: {
                                            if let oldDate { PlannerRepository(context: modelContext).updateDate(taskKey: key, to: oldDate) }
                                            if let uid = auth.uid {
                                                Task { await FirestoreTaskStateService.shared.push(uid: uid, taskKey: key, modelContext: modelContext) }
                                            }
                                        },
                                        redo: {
                                            PlannerRepository(context: modelContext).updateDate(taskKey: key, to: newDate)
                                            if let uid = auth.uid {
                                                Task { await FirestoreTaskStateService.shared.push(uid: uid, taskKey: key, modelContext: modelContext) }
                                            }
                                        }
                                    ))
                                    showUndoToastTemporarily()
                                },
                                onMarkDone: { key in
                                    withAnimation(.spring) { adapter.markDone(key) }
                                    if let uid = auth.uid {
                                        Task { await FirestoreTaskStateService.shared.push(uid: uid, taskKey: key, modelContext: modelContext) }
                                    }

                                    timelineUndo.push(.init(
                                        label: "Marked as done",
                                        undo: {
                                            PlannerRepository(context: modelContext).toggleDone(taskKey: key) // toggling reverts
                                            if let uid = auth.uid {
                                                Task { await FirestoreTaskStateService.shared.push(uid: uid, taskKey: key, modelContext: modelContext) }
                                            }
                                        },
                                        redo: {
                                            PlannerRepository(context: modelContext).toggleDone(taskKey: key)
                                            if let uid = auth.uid {
                                                Task { await FirestoreTaskStateService.shared.push(uid: uid, taskKey: key, modelContext: modelContext) }
                                            }
                                        }
                                    ))
                                    showUndoToastTemporarily()
                                },
                                onSnooze: { key, comps in
                                    let repo = PlannerRepository(context: modelContext)
                                    let oldDate = repo.item(for: key)?.dueDate
                                    // Perform snooze (adapter computes new date)
                                    withAnimation(.spring) { adapter.snooze(key, by: comps) }
                                    let newDate = PlannerRepository(context: modelContext).item(for: key)?.dueDate

                                    if let uid = auth.uid {
                                        Task { await FirestoreTaskStateService.shared.push(uid: uid, taskKey: key, modelContext: modelContext) }
                                    }

                                    timelineUndo.push(.init(
                                        label: "Snoozed to \(newDate?.formatted(date: .abbreviated, time: .shortened) ?? "later")",
                                        undo: {
                                            if let oldDate { PlannerRepository(context: modelContext).updateDate(taskKey: key, to: oldDate) }
                                            if let uid = auth.uid {
                                                Task { await FirestoreTaskStateService.shared.push(uid: uid, taskKey: key, modelContext: modelContext) }
                                            }
                                        },
                                        redo: {
                                            if let newDate { PlannerRepository(context: modelContext).updateDate(taskKey: key, to: newDate) }
                                            if let uid = auth.uid {
                                                Task { await FirestoreTaskStateService.shared.push(uid: uid, taskKey: key, modelContext: modelContext) }
                                            }
                                        }
                                    ))
                                    showUndoToastTemporarily()
                                },
                                onOpenDetail: { key in
                                    if let task = TaskRepository.task(forKey: key) { navTask = task }
                                }
                            )
                            .padding(.top, 4)
                        }
                        // Shake to undo
                        .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
                            if timelineUndo.lastEvent != nil {
                                timelineUndo.undoLast()
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            }
                        }
                        .safeAreaInset(edge: .bottom) {
                            if tab == .timeline, showUndoPrompt, let evt = timelineUndo.lastEvent {
                                UndoBanner(label: evt.label) {
                                    timelineUndo.undoLast()
                                    showUndoPrompt = false
                                }
                                .padding(.horizontal, 16)   // side gutters
                                .padding(.bottom, 6)        // sits just above the tab bar
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Planner")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $editingSDItem) { it in
                DateEditorSheetSD(item: it)
                    .environment(\.modelContext, modelContext)
            }
            .navigationDestination(item: $navTask) { task in
                TaskDetailView(item: task)
            }
        }
        // Respond to widget deep link: pathmate://task/<taskKey>
        .onReceive(NotificationCenter.default.publisher(for: .openTaskFromWidget)) { note in
            if let key = note.userInfo?["id"] as? String,
               let task = TaskRepository.task(forKey: key) {
                tab = .scheduled
                navTask = task
            }
        }
    }
}

private extension PlannerView {
    func showUndoToastTemporarily() {
        withAnimation { showUndoPrompt = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showUndoPrompt = false }
        }
    }
}

private struct UndoBanner: View {
    let label: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .imageScale(.large)
            Text(label)
                .lineLimit(1)
                .font(.subheadline)
            Spacer(minLength: 8)
            Button("Undo", action: onUndo)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(radius: 4, y: 2)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(label + ", Undo available"))
    }
}

private struct PlannerCard: View {
    let task: ChecklistTask
    let stage: StageID
    let dueDate: Date?
    let isCompleted: Bool
    let doneAt: Date?

    // Overdue when not completed and due date is in the past
    private var isOverdue: Bool {
        guard !isCompleted, let d = dueDate else { return false }
        return d < Date()
    }
    
    private var cardBackground: Color {
        isCompleted
            ? Color.green.opacity(0.10)               // Completed tab
            : tintFor(stage: stage).opacity(0.10)     // Scheduled tab
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolFor(stage: stage))
                .imageScale(.large)
                .foregroundStyle(tintFor(stage: stage))
                .frame(width: 30, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                // Title + Overdue badge on the right
                HStack(alignment: .firstTextBaseline) {
                    Text(task.title).font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if isOverdue {
                        overdueBadge
                            .accessibilityLabel("Overdue")
                    }
                }

                if isCompleted {
                    Text(doneLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let due = dueDate {
                    Text(dateLabel(for: due))
                        .font(.subheadline)
                        .foregroundStyle(isOverdue ? .red : .secondary)
                } else {
                    Text("No date")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardBackground)
        )
    }

    // MARK: - Subviews

    private var overdueBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .imageScale(.small)
            Text("Overdue")
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundStyle(Color.red)
        .background(Color.red.opacity(0.14), in: Capsule())
    }

    // MARK: - Formatting

    private var doneLabel: String {
        if let d = doneAt {
            return "Done " + d.formatted(.dateTime.weekday(.abbreviated).day().hour().minute())
        }
        return "Done"
    }

    private func dateLabel(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today " + date.formatted(date: .omitted, time: .shortened) }
        if cal.isDateInTomorrow(date)  { return "Tomorrow " + date.formatted(date: .omitted, time: .shortened) }
        return date.formatted(.dateTime.weekday(.abbreviated).day().hour().minute())
    }

    private func symbolFor(stage: StageID) -> String {
        switch stage {
        case .preDeparture:   return "airplane.departure"
        case .arrival:        return "figure.wave"
        case .university:     return "graduationcap"
        case .workCompliance: return "briefcase"
        case .lifeBalance:    return "heart"
        }
    }

    private func tintFor(stage: StageID) -> Color {
        switch stage {
        case .preDeparture:   return .blue
        case .arrival:        return .purple
        case .university:     return .indigo
        case .workCompliance: return .orange
        case .lifeBalance:    return .green
        }
    }
}

private struct DateEditorSheetSD: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var auth: AuthService

    let item: PlannerRepository.Item
    @State private var date: Date = Date()

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("Due date", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                Spacer()
            }
            .navigationTitle("Change date")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        withAnimation {
                            PlannerRepository(context: modelContext)
                                .updateDate(taskKey: item.taskKey, to: date)
                        }
                        if let uid = auth.uid {
                            Task { await FirestoreTaskStateService.shared.push(uid: uid, taskKey: item.taskKey, modelContext: modelContext) }
                        }
                        dismiss()
                    }
                }
            }
        }
        .onAppear { date = item.dueDate ?? Date() }
    }
}
