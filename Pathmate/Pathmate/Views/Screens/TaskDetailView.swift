//
//  TaskDetailView.swift
//  Pathmate
//
//  Created by Omkar Lad on 27/8/2025.
//

// MARK: - Imports
// SwiftUI for scrolling layout, materials, and navigation.
// SwiftData for local persistence and reactive updates.
import SwiftUI
import SwiftData

/// **TaskDetailView**
///
/// Detail screen for a single checklist task. Presents the task’s title,
/// optional subtitle, “What/Why” info cards, ordered steps, and useful links,
/// with a sticky bottom action bar for **Add to planner** and **Mark as Done**.
///
/// - SeeAlso: ``ChecklistTask``, ``TaskDetail``
struct TaskDetailView: View {
    /// The checklist task being displayed.
    let item: ChecklistTask

    /// System URL opener available for handling external links if needed.
    @Environment(\.openURL) private var openURL

    // SwiftData context to persist planner/done state
    @Environment(\.modelContext) private var modelContext
    
    @EnvironmentObject private var auth: AuthService

    // Watch all task states so this view refreshes immediately on any change.
    @Query private var allStates: [TaskStateEntity]

    /// Controls presentation of the due-date picker sheet.
    @State private var showDateSheet = false

    /// Temporary date bound to the sheet's `DatePicker`.
    @State private var tempDate = Date()

    // Derived state (computed from SwiftData)
    private var repo: PlannerRepository { PlannerRepository(context: modelContext) }
    private var state: PlannerRepository.Item? { repo.item(for: item.key) }

    /// Whether this task already exists in the planner.
    private var isInPlanner: Bool { state?.dueDate != nil }

    /// Completed state for this task.
    private var isDone: Bool { state?.isDone ?? false }

    /// Whether the planned instance of this task (if any) is overdue right now.
    private var isOverdueNow: Bool {
        if let s = state, let due = s.dueDate {
            return !s.isDone && due < Calendar.current.startOfDay(for: Date())
        }
        return false
    }

    /// A short "since" date string for the overdue label (e.g., "Mon 6").
    private var overdueSinceText: String {
        if let s = state, let due = s.dueDate {
            return due.formatted(.dateTime.weekday(.abbreviated).day())
        }
        return ""
    }

    // Hide planner button when task is done
    private var shouldShowPlannerCTA: Bool { !isDone }

    /// Scrollable content with extra bottom padding so it doesn’t sit under
    /// the sticky action bar. Inline nav title for compact hierarchy.
    var body: some View {
        // Reactivity anchor: any change in TaskStateEntity will recompute this body.
        let _ = allStates

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Title block
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.title.bold())
                        .foregroundStyle(.primary)

                    if !item.subtitle.isEmpty {
                        Text(item.subtitle)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    if isOverdueNow {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                            Text("Overdue since \(overdueSinceText)")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Overdue since \(overdueSinceText)")
                    }
                }

                // Info cards
                infoCard(icon: "questionmark.circle.fill",
                         tint: .blue,
                         title: "What is this?",
                         text: item.detail.what)

                infoCard(icon: "lightbulb.max.fill",
                         tint: .yellow,
                         title: "Why it matters",
                         text: item.detail.why)

                // Steps
                if !item.detail.steps.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Steps")
                            .font(.headline)

                        ForEach(Array(item.detail.steps.enumerated()), id: \.offset) { idx, step in
                            StepRow(number: idx + 1, text: step)
                        }
                    }
                }

                // Links
                if !item.detail.links.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Useful links")
                            .font(.headline)

                        ForEach(item.detail.links) { link in
                            LinkRow(label: link.label, urlString: link.url)
                        }
                    }
                }

            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 120)
        }
        .background(Color(.systemBackground))
        .navigationTitle("Task Detail")
        .navigationBarTitleDisplayMode(.inline)

        // Sticky bottom action bar
        .safeAreaInset(edge: .bottom) { actionBar }

        // Date picker sheet for "Add / Change date"
        .sheet(isPresented: $showDateSheet) { datePickerSheet }

        // Prefill date when we land here (use existing planner date or default to tomorrow)
        .onAppear {
            if let existing = repo.item(for: item.key)?.dueDate {
                tempDate = existing
            } else {
                tempDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            }
        }
    }

    // MARK: - Components
    /// Info card used for “What is this?” and “Why it matters”.
    ///
    /// - Parameters:
    ///   - icon: SF Symbol name shown leading.
    ///   - tint: Accent color for the icon.
    ///   - title: Section title (e.g., “What is this?”).
    ///   - text: Supporting body text.
    private func infoCard(icon: String, tint: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(text).font(.callout).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    /// Numbered step row in the **Steps** section (compact, wraps long text).
    private struct StepRow: View {
        let number: Int
        let text: String

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(number)")
                    .font(.footnote.bold())
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.accentColor))
                    .accessibilityHidden(true)

                Text(text)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// External resource link row with Safari glyph and tappable label.
    ///
    /// - Important: `urlString` is force-unwrapped for the prototype.
    ///   In production, validate the string → `URL` safely.
    private struct LinkRow: View {
        let label: String
        let urlString: String

        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: "safari")
                    .foregroundStyle(.tint)
                Link(label, destination: URL(string: urlString)!)
                    .font(.callout)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Sticky action bar & sheets

    /// Sticky bottom action bar with Add/Remove and Done/Undone logic.
    private var actionBar: some View {
        VStack(spacing: 12) {
            // 1) Add / Remove planner — only when NOT done
            if shouldShowPlannerCTA {
                Button {
                    if isInPlanner {
                        withAnimation { repo.remove(taskKey: item.key) }
                        if let uid = auth.uid {
                            Task { await FirestoreTaskStateService.shared.push(uid: uid, taskKey: item.key, modelContext: modelContext) }
                        }
                    } else {
                        showDateSheet = true
                    }
                } label: {
                    Label(isInPlanner ? "Remove from planner" : "Add to planner",
                          systemImage: isInPlanner ? "calendar.badge.minus" : "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }

            // 2) Done / Undone toggle (always visible)
            Button {
                withAnimation { repo.toggleDone(taskKey: item.key) }
                if let uid = auth.uid {
                    Task { await FirestoreTaskStateService.shared.push(uid: uid, taskKey: item.key, modelContext: modelContext) }
                }
            } label: {
                Label(isDone ? "Mark as undone" : "Mark as Done",
                      systemImage: isDone ? "arrow.uturn.backward.circle" : "checkmark.circle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .top)
    }

    /// Sheet hosting a graphical `DatePicker` to set or change the due date.
    private var datePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 12) {
                DatePicker("Due date", selection: $tempDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()

                Spacer()
            }
            .navigationTitle(isInPlanner ? "Change date" : "Add to planner")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showDateSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Add or update in SwiftData
                        if let sid = inferStageID(for: item) {
                            withAnimation { repo.add(task: item, stageID: sid, dueDate: tempDate) }
                            if let uid = auth.uid {
                                Task { await FirestoreTaskStateService.shared.push(uid: uid, taskKey: item.key, modelContext: modelContext) }
                            }
                        }
                        showDateSheet = false
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Attempts to resolve the `StageID` that owns this checklist task.
    ///
    /// Scans the static repository to find a matching `key`. This keeps the
    /// view independent of external state while still maintaining correctness.
    /// - Returns: The stage identifier if found, otherwise `nil`.
    private func inferStageID(for task: ChecklistTask) -> StageID? {
        for sid in StageID.allCases {
            if TaskRepository.tasks(for: sid).contains(where: { $0.key == task.key }) {
                return sid
            }
        }
        return nil
    }
}
