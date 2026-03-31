//
//  HomeView.swift
//  Pathmate
//
//  Created by Kshitija on 27/8/2025.
//

// MARK: - Imports
// SwiftUI for navigation, layout, lists, and materials.
import SwiftUI
import SwiftData

// MARK: - HOME

/// **HomeView (Dashboard)**
///
/// Landing screen summarising journey progress, today’s plan, next tasks,
/// and upcoming reminders. Sections are lightweight, tappable summaries that
/// deep-link to their respective screens.
///
/// The main dashboard composed of four sections:
/// progress card, scheduled tasks, next tasks, and reminders.
/// - SeeAlso: ``JourneyView``, ``ChecklistView``
struct HomeView: View {
    /// Scrollable dashboard wrapped in a `NavigationStack` with inline title.
    let profile: UserProfile
    @StateObject private var jvm = JourneyViewModel()

    // SwiftData model context (used to read the persisted profile and task states)
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var auth: AuthService

    // Observe all task states so the dashboard refreshes live on changes.
    @Query private var taskStates: [TaskStateEntity]

    @State private var persistedName: String = ""

    /// Name to show in the greeting (prefer persisted SwiftData value if present).
    private var greetingName: String {
        let local = profile.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let stored = persistedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return stored.isEmpty ? local : stored
    }

    // MARK: - Progress (SwiftData-backed via ProgressRepository)
    private func stageProgress(_ id: StageID) -> Double {
        let repo = ProgressRepository(context: modelContext)
        return repo.progress(for: id, tasks: jvm.tasks(for: id))
    }

    private var overallProgress: Double {
        let repo = ProgressRepository(context: modelContext)
        var total = 0, done = 0
        for sid in jvm.stages.map(\.id) {
            let tasks = jvm.tasks(for: sid)
            total += tasks.count
            done  += tasks.filter { repo.isDone($0.key) }.count
        }
        return total == 0 ? 0 : Double(done) / Double(total)
    }

    var body: some View {
        NavigationStack {
            // Reactivity anchor: recompute when any TaskStateEntity changes.
            let _ = taskStates

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // GREETING
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hi, \(greetingName) 👋")
                            .font(.largeTitle.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text("Here’s your journey today")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // PROGRESS: Ring + stages card
                    ProgressCard(
                        overall: overallProgress,
                        pre:     stageProgress(.preDeparture),
                        arrival: stageProgress(.arrival),
                        uni:     stageProgress(.university)
                    )

                    // SCHEDULED TASKS (SwiftData-backed, UI unchanged)
                    TodayPlanSection(jvm: jvm)

                    // NEXT 3 TASKS (SwiftData-backed checks, UI unchanged)
                    NextTasksSection(jvm: jvm)

                    // REMINDERS
                    RemindersSection()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            // Load persisted name once when Home appears.
            .task {
                do {
                    let d = FetchDescriptor<UserProfileEntity>()
                    if let row = try modelContext.fetch(d).first {
                        persistedName = row.fullName
                    }
                } catch {
                    // Non-fatal; greeting will fall back to the in-memory profile.
                }
            }
            .navigationTitle("") // stays clean
            .navigationBarHidden(true)
        }
    }
}

private struct UnscheduledPick: Identifiable {
    let task: ChecklistTask
    let stage: StageID
    var id: String { task.key }   // stable id
}

// MARK: - Sections

/// **TodayPlanSection**
///
/// Shows scheduled task blocks with a quick link to Planner.
///
/// - Important: Data now comes from SwiftData (`PlannerRepository`) so it
///   persists across relaunches. UI stays exactly the same.
private struct TodayPlanSection: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var auth: AuthService
    @Query private var taskStates: [TaskStateEntity]   // observe changes
    let jvm: JourneyViewModel

    // Edit date sheet state
    @State private var editingBlock: PlanBlock?
    @State private var editDate: Date = Date()

    var body: some View {
        // Reactivity anchor (drives refresh for scheduled tiles)
        let _ = taskStates

        // SwiftData scheduled (first 4)
        let repo = PlannerRepository(context: modelContext)
        let scheduledItems = Array(repo.scheduled().prefix(4))

        Group {
            if scheduledItems.isEmpty {
                Text("On your calendar")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                // Full-width empty-state card → Journey
                NavigationLink(destination: JourneyView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.plus")
                            .imageScale(.large)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No tasks scheduled").font(.headline)
                            Text("Add something to your planner")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
                .buttonStyle(.plain)
            } else {
                // Map SwiftData items into your existing PlanBlock tiles
                let tiles: [PlanBlock] = scheduledItems.compactMap { it in
                    guard let stage = StageID(rawValue: it.stageRaw),
                          let task  = TaskRepository.tasks(for: stage).first(where: { $0.key == it.taskKey }),
                          let due   = it.dueDate else { return nil }
                    return PlanBlock(
                        title: task.title,
                        time: formattedTime(due),
                        symbol: symbolFor(stage: stage),
                        tint: colorFor(stage: stage),
                        isDone: it.isDone,
                        taskKey: it.taskKey,
                        stageID: stage,
                        dueDate: due
                    )
                }

                TodayPlanGrid(
                    title: "On your calendar",
                    items: tiles,
                    onEditTap: { block in
                        editDate = block.dueDate ?? Date()
                        editingBlock = block
                    },
                    onDoneTap: { block in
                        guard let key = block.taskKey else { return }
                        // Persist completion in SwiftData
                        PlannerRepository(context: modelContext).toggleDone(taskKey: key)
                        if let uid = auth.uid {
                            Task { await FirestoreTaskStateService.shared.push(uid: uid, taskKey: key, modelContext: modelContext) }
                        }
                    }
                )
            }
        }
        // Attach the sheet to the Group so it applies regardless of branch
        .sheet(item: $editingBlock) { block in
            NavigationStack {
                VStack(spacing: 12) {
                    DatePicker("Due date", selection: $editDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                    Spacer()
                }
                .navigationTitle("Edit date")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { editingBlock = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            if let key = block.taskKey {
                                PlannerRepository(context: modelContext).updateDate(taskKey: key, to: editDate)
                                if let uid = auth.uid {
                                    Task { await FirestoreTaskStateService.shared.push(uid: uid, taskKey: key, modelContext: modelContext) }
                                }
                            }
                            editingBlock = nil
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers (same logic you already use)
    private func formattedTime(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        } else if cal.isDateInTomorrow(date) {
            return "Tomorrow " + date.formatted(date: .omitted, time: .shortened)
        } else {
            return date.formatted(.dateTime.weekday(.abbreviated).day().hour().minute())
        }
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

    private func colorFor(stage: StageID) -> Color {
        switch stage {
        case .preDeparture:   return .blue
        case .arrival:        return .purple
        case .university:     return .indigo
        case .workCompliance: return .orange
        case .lifeBalance:    return .green
        }
    }
}

/// **NextTasksSection**
///
/// Lists the next three actionable tasks with shortcuts to add/mark done.
///
/// - Important: Scheduling/done checks use SwiftData (`TaskStateEntity`),
///   so the list persists correctly across relaunches.
private struct NextTasksSection: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var auth: AuthService
    @Query private var taskStates: [TaskStateEntity]   // observe changes
    let jvm: JourneyViewModel   // injected from HomeView

    // For the "Add to planner" flow
    @State private var schedulingPick: UnscheduledPick?
    @State private var tempDate: Date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()

    var body: some View {
        // Reactivity anchor (drives refresh for “Next 3”)
        let _ = taskStates

        let picks: [UnscheduledPick] = topUnscheduled(limit: 3)

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Next 3 tasks")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                NavigationLink(destination: JourneyView()) {
                    Text("See all").font(.subheadline).foregroundStyle(.blue)
                }.buttonStyle(.plain)
            }

            if picks.isEmpty {
                Text("Everything’s either scheduled or done 🎉")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(picks.enumerated()), id: \.offset) { pair in
                        let entry = pair.element
                        let task  = entry.task
                        let stage = entry.stage

                        TaskLine(
                            title: task.title,
                            subtitle: subtitle(stage: stage, task: task),
                            tint: stageTint(for: stage),
                            onAddToPlanner: {
                                tempDate = defaultTomorrow()
                                schedulingPick = entry
                            },
                            onDone: {
                                // Persist done in SwiftData (ensures it moves to Completed)
                                PlannerRepository(context: modelContext).ensureAndComplete(task: task, stageID: stage)
                                if let uid = auth.uid {
                                    Task { await FirestoreTaskStateService.shared.push(uid: uid, taskKey: task.key, modelContext: modelContext) }
                                }
                            }
                        )
                    }
                }
            }
        }
        // Date picker sheet for "Add to planner"
        .sheet(item: $schedulingPick) { pick in
            NavigationStack {
                VStack(spacing: 12) {
                    DatePicker("Due date", selection: $tempDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                    Spacer()
                }
                .navigationTitle("Add to planner")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { schedulingPick = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            PlannerRepository(context: modelContext).add(task: pick.task, stageID: pick.stage, dueDate: tempDate)
                            if let uid = auth.uid {
                                Task { await FirestoreTaskStateService.shared.push(uid: uid, taskKey: pick.task.key, modelContext: modelContext) }
                            }
                            schedulingPick = nil
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Up to `limit` tasks that are NOT scheduled and NOT done.
    /// Uses SwiftData `TaskStateEntity` to check status.
    private func topUnscheduled(limit: Int) -> [UnscheduledPick] {
        var result: [UnscheduledPick] = []
        for sid in StageID.allCases {
            for task in jvm.tasks(for: sid) {
                let s = sdState(for: task.key)
                let isScheduled = (s?.dueDate != nil)
                let isDone = (s?.isDone == true)
                if !isScheduled && !isDone {
                    result.append(UnscheduledPick(task: task, stage: sid))
                    if result.count == limit { return result }
                }
            }
        }
        return result
    }

    /// Fetches a single SwiftData state row for a task key (if any).
    private func sdState(for key: String) -> TaskStateEntity? {
        let d = FetchDescriptor<TaskStateEntity>(predicate: #Predicate { $0.taskKey == key })
        return (try? modelContext.fetch(d))?.first
    }

    private func subtitle(stage: StageID, task: ChecklistTask) -> String {
        if !task.subtitle.isEmpty { return task.subtitle }
        switch stage {
        case .preDeparture:   return "Pre-departure"
        case .arrival:        return "Arrival"
        case .university:     return "University"
        case .workCompliance: return "Work & Compliance"
        case .lifeBalance:    return "Life & Balance"
        }
    }

    private func defaultTomorrow() -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    }
    private func stageTint(for stage: StageID) -> Color {
        // Use the JourneyViewModel stages to find the matching tint color.
        if let s = jvm.stages.first(where: { $0.id == stage }) {
            return s.tint.color
        }
        return .blue
    }
}

// MARK: - Components

/// **ProgressCard**
///
/// Card combining overall circular progress with per-stage linear progress rows.
private struct ProgressCard: View {
    let overall: Double
    let pre: Double
    let arrival: Double
    let uni: Double

    var body: some View {
        HStack(spacing: 18) {
            ProgressRing(value: overall, lineWidth: 10, size: 88,
                         tint: .blue, background: .gray.opacity(0.2)) {
                VStack(spacing: 2) {
                    Text("\(Int(overall * 100))%").font(.headline.monospacedDigit())
                    Text("Overall").font(.caption2).foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 10) {
                StageProgressRow(title: "Pre-departure",
                                 percent: pre, tint: .blue,
                                 symbol: "airplane.departure")
                StageProgressRow(title: "Arrival",
                                 percent: arrival, tint: .purple,
                                 symbol: "figure.wave")
                StageProgressRow(title: "University",
                                 percent: uni, tint: .indigo,
                                 symbol: "graduationcap")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// **ProgressRing**
///
/// Reusable circular progress indicator with custom center content.
///
/// - Parameters:
///   - value: Progress fraction in `0.0...1.0`.
///   - lineWidth: Stroke width for rings.
///   - size: Square side length in points.
///   - tint: Foreground ring color.
///   - background: Track color behind the ring.
/// - Important: `value` must be within `0.0...1.0`.
private struct ProgressRing<Center: View>: View {
    let value: Double, lineWidth: CGFloat, size: CGFloat
    let tint: Color, background: Color
    let center: Center
    init(value: Double, lineWidth: CGFloat, size: CGFloat,
         tint: Color, background: Color,
         @ViewBuilder center: () -> Center) {
        self.value = value; self.lineWidth = lineWidth; self.size = size
        self.tint = tint; self.background = background; self.center = center()
    }
    var body: some View {
        ZStack {
            Circle().stroke(background, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, value)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Overall progress")
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

/// **StageProgressRow**
///
/// Compact row showing a stage symbol, title, and linear percentage.
private struct StageProgressRow: View {
    let title: String
    let percent: Double
    let tint: Color
    var symbol: String = "checkmark.seal"

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.subheadline.weight(.semibold))
                ProgressView(value: percent)
                    .progressViewStyle(.linear)
                    .tint(tint)
            }
            Spacer(minLength: 8)
            Text("\(Int(percent * 100))%")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// **TaskLine**
///
/// Task preview row with duration pill, swipe actions, and context menu.
///
/// - Parameters:
///   - title: Task title (primary).
///   - subtitle: Short context (secondary).
///   - duration: Estimated time (e.g., “45 min”).
///   - onAddToPlanner: Callback to add the task to planner.
///   - onDone: Callback to mark the task as done.
private struct TaskLine: View {
    let title: String
    let subtitle: String
    let tint: Color
    let duration: String? = nil
    var onAddToPlanner: () -> Void = {}
    var onDone: () -> Void = {}

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "circle").foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if let duration {
                Text(duration)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.10), lineWidth: 1)
                    )
            }
        }
        .padding(14)
        .background(tint.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .tint(tint)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(action: onDone) {
                Label("Mark done", systemImage: "checkmark.circle.fill")
            }
            .tint(.green)

            Button(action: onAddToPlanner) {
                Label("Add to planner", systemImage: "calendar.badge.plus")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button(action: onAddToPlanner) { Label("Add to planner", systemImage: "calendar.badge.plus") }
            Button(action: onDone)         { Label("Mark done", systemImage: "checkmark.circle") }
        }
    }
}

/// **PlanTile**
///
/// Tile for a planned block (title + time + SF Symbol) in Today’s plan grid.
private struct PlanTile: View {
    let title: String
    let time: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.semibold))
                Text(time).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .frame(minHeight: 92)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// **RemindersSection**
///
/// Card of upcoming reminders with a small tip chip and dividers.
private struct RemindersSection: View {
    /// Simple reminder item model (title + detail).
    struct Item: Identifiable {
        let id = UUID(); let title: String; let detail: String
    }
    private let items: [Item] = [
        .init(title: "TFN follow-up", detail: "ATO confirmation may take ~28 days"),
        .init(title: "Orientation week", detail: "Mon 9:00 AM — add sessions")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming reminders").font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("Tip: Small steps count 💡")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.12))
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(items.indices, id: \.self) { i in
                    ReminderLine(dot: .yellow,
                                 title: items[i].title,
                                 detail: items[i].detail)
                    if i < items.count - 1 {
                        Divider()
                            .padding(.leading, 18)
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

/// **ReminderLine**
///
/// Single reminder row with a colored dot, title, and detail.
private struct ReminderLine: View {
    let dot: Color, title: String, detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(dot).frame(width: 8, height: 8).padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold))
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    var p = UserProfile()
    p.fullName = "Omkar"
    return HomeView(profile: p)
}
