//
//  TodayPlanGrid.swift
//  Pathmate
//
//  Created by Omkar Lad on 11/10/2025.
//

import SwiftUI

// MARK: - Model for scheduled tasks tiles

/// A small, static model used by `TodayPlanGrid`.
///
/// - Note: Conforms to `Identifiable`, `Equatable`, and `Hashable` so it
///   can be used inside `ForEach` and for index lookups during reordering.
struct PlanBlock: Identifiable, Equatable, Hashable {
    let id = UUID()
    var title: String
    var time: String
    var symbol: String
    var tint: Color
    var isDone: Bool = false

    // Link back to real planner data
    var taskKey: String? = nil
    var stageID: StageID? = nil
    var dueDate: Date? = nil
}

// PreferenceKey to read each cell's frame for hit-testing during drag

/// Captures each grid cell's frame (in the grid coordinate space) so we can
/// detect when the dragged finger hovers another card and perform a swap.
private struct BlockFrameKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// A reusable grid that powers **Today’s plan** on Home.
///
/// ### Custom Multi-Gesture
/// - **Sequence:** `LongPressGesture` → `DragGesture`
///   Lifts a tile (enters edit mode) and lets the user drag to reorder.
///
/// This composition matches iOS mental models (Home Screen jiggle+reorder),
/// but is customized for Pathmate’s small schedule tiles.
///
/// - Parameters:
///   - title: Section header text (e.g., "Today’s plan").
struct TodayPlanGrid: View {
    // configurable header
    var title: String = "On your calendar"
    
    var source: [PlanBlock] = []
    
    // optional action handlers (parent can override default behavior)
    var onEditTap: ((PlanBlock) -> Void)? = nil
    var onDoneTap: ((PlanBlock) -> Void)? = nil

    @State private var items: [PlanBlock] = []
    // Editing + drag state
    @State private var isEditing = false
    @State private var frames: [UUID: CGRect] = [:]
    @State private var draggingID: UUID?
    @State private var dragOffsets: [UUID: CGSize] = [:]
    @State private var reorderedInCurrentDrag = false
    @State private var showingActionsFor: PlanBlock?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    init(
        title: String = "On your calendar",
        items: [PlanBlock],
        onEditTap: ((PlanBlock) -> Void)? = nil,
        onDoneTap: ((PlanBlock) -> Void)? = nil
    ) {
        self.title = title
        self.source = items
        self._items = State(initialValue: items)
        self.onEditTap = onEditTap
        self.onDoneTap = onDoneTap
    }
       
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title).font(.headline).accessibilityAddTraits(.isHeader)
                Spacer()
                if isEditing {
                    Text("Drag to reorder")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Button {
                    // Explicit "Done" — stop jiggle and clear drag state immediately
                    withAnimation(.spring) {
                        isEditing.toggle()
                        if !isEditing {
                            draggingID = nil
                            dragOffsets.removeAll()
                            reorderedInCurrentDrag = false
                        }
                    }
                } label: { Text(isEditing ? "Done" : "Edit") }
                .font(.subheadline)

                Text("•")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                NavigationLink(destination: PlannerView()) {
                    Text("See all").font(.subheadline).foregroundStyle(.blue)
                }.buttonStyle(.plain)
            }

            .onChange(of: source) { oldValue, newValue in
                // don’t clobber while user is dragging/reordering
                guard !isEditing, draggingID == nil else { return }
                items = newValue
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(items) { item in
                    // Per-card jiggle state:
                    // - While editing, all non-dragged cards jiggle.
                    // - The dragged card does NOT jiggle (prevents jitter).
                    let cardJiggleActive = isEditing && draggingID != item.id

                    PlanBlockCard(
                        item: item,
                        isEditing: isEditing,
                        isDragging: draggingID == item.id,
                        jiggleActive: cardJiggleActive
                    )
                    .offset(dragOffsets[item.id] ?? .zero)
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: BlockFrameKey.self,
                                value: [item.id: proxy.frame(in: .named("gridSpace"))]
                            )
                        }
                    )
                    .onTapGesture { showingActionsFor = item }

                    // --- Custom multi-gesture composition ---
                    // Sequenced: long-press then drag (to reorder)
                    .gesture(longPressThenDrag(for: item))
                    .contextMenu { actionMenu(for: item) }
                }
            }
            .coordinateSpace(name: "gridSpace")
            .onPreferenceChange(BlockFrameKey.self) { frames = $0 }
        }
        .confirmationDialog(showingActionsFor?.title ?? "",
                            isPresented: Binding(get: { showingActionsFor != nil },
                                                 set: { if !$0 { showingActionsFor = nil } })) {
            if let b = showingActionsFor { actionButtons(for: b) }
        }
    }

    // MARK: - Gestures

    /// Returns a composed gesture for a single tile:
    /// 1) **Long press** to lift and enter edit mode.
    /// 2) **Drag** to hover over other tiles and reorder by swapping.
    // Builds a sequenced gesture
    private func longPressThenDrag(for item: PlanBlock) -> some Gesture {
        let lift = LongPressGesture(minimumDuration: 0.18)
            .onEnded { _ in
                withAnimation(.spring) {
                    isEditing = true
                    draggingID = item.id
                    reorderedInCurrentDrag = false  // reset for this drag
                    // fire a soft haptic for tactile feedback
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
            }

        let drag = DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard let start = frames[item.id] else { return }
                dragOffsets[item.id] = value.translation

                // Finger point in grid space
                let current = CGPoint(
                    x: start.midX + value.translation.width,
                    y: start.midY + value.translation.height
                )

                // If hovering over another block, reorder
                if let (targetID, _) = frames.first(where: { $0.key != item.id && $0.value.contains(current) }),
                   let from = items.firstIndex(where: { $0.id == item.id }),
                   let to = items.firstIndex(where: { $0.id == targetID }),
                   from != to {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        items.move(fromOffsets: IndexSet(integer: from),
                                   toOffset: to > from ? to + 1 : to)
                        reorderedInCurrentDrag = true   // mark a real swap
                    }
                }
            }
            .onEnded { _ in
                withAnimation(.spring) {
                    dragOffsets[item.id] = .zero
                    draggingID = nil
                    // Auto-exit edit mode after a proper reorder:
                    if reorderedInCurrentDrag {
                        isEditing = false
                    }
                }
                reorderedInCurrentDrag = false
            }

        return lift.sequenced(before: drag)
    }

    // MARK: - Actions

    /// Context menu actions shown on long press or tap (via confirmation dialog).
    @ViewBuilder
    private func actionMenu(for item: PlanBlock) -> some View {
        Button("Edit") {
            if let onEditTap { onEditTap(item) } else {
                // fallback to old behavior if not provided
                showingActionsFor = item
            }
        }
        Button(item.isDone ? "Mark as not done" : "Mark as done") {
            if let onDoneTap {
                onDoneTap(item)
            } else if let i = items.firstIndex(of: item) {
                // local demo fallback
                items[i].isDone.toggle()
            }
        }
    }

    /// The same actions rendered inside `confirmationDialog`.
    @ViewBuilder
    private func actionButtons(for item: PlanBlock) -> some View {
        actionMenu(for: item)
    }
}

// MARK: - Card view with jiggle while editing and optional drag halo

/// Visual card for a `PlanBlock`.
/// - Displays symbol, title, time, and a done check.
/// - Jiggles while the grid is in edit mode (iOS 17+ `phaseAnimator`).
struct PlanBlockCard: View {
    let item: PlanBlock
    let isEditing: Bool
    let isDragging: Bool
    let jiggleActive: Bool   // controls jiggle for THIS card

    @State private var phaseSeed = Double.random(in: 0...1)

    // Overdue logic (not done + dueDate in the past)
    private var isOverdue: Bool {
        guard !item.isDone, let d = item.dueDate else { return false }
        return d < Date()
    }

    var body: some View {
        // Base content (no jiggle)
        let base = ZStack {
            // Stage-tinted background
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(item.tint.opacity(0.10))

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: item.symbol)
                    .foregroundStyle(item.tint)
                    .frame(width: 24, alignment: .leading)     // fixed width for alignment

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.body.weight(.semibold)).lineLimit(1)
                            .foregroundStyle(.primary)
                        if item.isDone {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .imageScale(.small)
                        }
                    }
                    Text(item.time)
                        .font(.subheadline)
                        .foregroundStyle(isOverdue ? .red : .secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                // Trailing overdue icon (no text) when past due
                if isOverdue {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                        .imageScale(.medium)
                        .accessibilityLabel("Overdue")
                }
            }
            .padding(16)

            if isDragging {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.tint, lineWidth: 2).padding(2)
            }
        }
        .frame(height: 92)
        .shadow(color: .black.opacity(isDragging ? 0.18 : 0.06),
                radius: isDragging ? 8 : 4, y: isDragging ? 6 : 2)

        // Apply jiggle only when active; otherwise return base as-is (no animation running).
        Group {
            if jiggleActive {
                base
                    // multi-step animation - used to give jiggle effect
                    .phaseAnimator([false, true], trigger: jiggleActive) { view, phase in
                        view
                            .rotationEffect(.degrees(phase ? 2.1 : -2.1))
                            .offset(x: phase ? 0.6 : -0.6)
                    } animation: { _ in
                        .easeInOut(duration: 0.12)
                        .repeatForever(autoreverses: true)
                        .delay(phaseSeed * 0.22)
                    }
            } else {
                base
                    .rotationEffect(.degrees(0))
                    .offset(x: 0)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(item.title), \(item.time)\(isOverdue ? ", overdue" : "")"))
        .accessibilityAddTraits(.isButton)
    }
}
