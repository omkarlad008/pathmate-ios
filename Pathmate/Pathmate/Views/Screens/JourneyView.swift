//
//  JourneyView.swift
//  Pathmate
//
//  Created by Omkar Lad on 27/8/2025.
//

// MARK: - Imports
// SwiftUI for navigation, layout, and list composition.
import SwiftUI
import SwiftData

/// **JourneyView**
///
/// Lists all journey stages as tappable cards. Each card shows title, subtitle,
/// icon and progress, and navigates to the stage’s checklist.
///
/// A screen that presents the full journey as a vertical list of stages.
/// Layout: a page header (title + subtitle) followed by a scrollable stack
/// of stage rows. Selecting a row pushes the corresponding checklist.
///
/// - SeeAlso: ``Stage``, ``StageRow``, ``ChecklistView``, ``JourneyViewModel``
struct JourneyView: View {
    /// View model publishing the ordered list of stages.
    @StateObject private var vm = JourneyViewModel()

    // SwiftData
    @Environment(\.modelContext) private var modelContext
    // Observe task states so progress bars refresh live.
    @Query private var taskStates: [TaskStateEntity]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your journey")
                            .font(.largeTitle.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text("Track your progress across stages")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)

                    VStack(spacing: 12) {
                        ForEach(vm.stages, id: \.id) { stage in
                            let repo = ProgressRepository(context: modelContext)
                            let percent = repo.progress(for: stage.id, tasks: vm.tasks(for: stage.id))

                            NavigationLink {
                                ChecklistView(stage: stage)
                            } label: {
                                StageRow(icon: stage.symbol,
                                         tint: stage.tint.color,
                                         title: stage.title,
                                         subtitle: stage.subtitle,
                                         progress: percent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 20)
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// Design-time preview for iterative layout checks.
#Preview { JourneyView() }
