//
//  PathmateWidget.swift
//  PathmateWidget
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Entry
/// Timeline entry carrying the timestamp and the widget snapshot.
struct Entry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

// MARK: - Provider
/// Builds timeline entries from the App Group snapshot (or placeholder for previews).
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: .now, snapshot: WidgetBridge.read() ?? .empty))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = Entry(date: .now, snapshot: WidgetBridge.read() ?? .empty)
        completion(Timeline(entries: [entry],
                            policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

// MARK: - Blue ring (matches Home)

private struct Ring: View {
    let fraction: Double
    let w: CGFloat = 6
    
    var body: some View {
        ZStack {
            Circle().inset(by: w / 2).stroke(.secondary.opacity(0.2), lineWidth: w)

            Circle()
                .inset(by: w / 2)
                .trim(from: 0, to: min(1, max(0, fraction)))
                .stroke(style: StrokeStyle(lineWidth: w, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .foregroundStyle(.blue)

            Text("\(Int(round(fraction * 100)))%")
                .font(.caption2).monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(width: 44, height: 44)
    }
}

// MARK: - View

struct PathmateWidgetView: View {
    let entry: Entry

    private var progress: Double {
        let total = entry.snapshot.overallTotal
        let done  = entry.snapshot.overallDone
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(done) / Double(total)))
    }

    var body: some View {
        HStack(spacing: 12) {
            Ring(fraction: progress)

            VStack(alignment: .leading, spacing: 6) {
                if entry.snapshot.next.isEmpty {
                    Text("No tasks scheduled")
                        .font(.subheadline).bold()
                    Text("Add something to your planner")
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    ForEach(entry.snapshot.next.prefix(3)) { t in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.title)
                                    .font(.subheadline).bold()
                                    .lineLimit(1)

                                HStack(spacing: 6) {
                                    // Overdue label red
                                    let overdue = isOverdue(t.scheduledDate)
                                    Text(shortDue(t.scheduledDate))
                                        .font(.caption2)
                                        .foregroundStyle(
                                            overdue
                                            ? .red
                                            : .secondary
                                        )

                                    if let stage = t.stageName, !stage.isEmpty {
                                        Text(stage)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            Spacer(minLength: 0)

                            // Interactive: mark as done via AppIntent (runs in app process)
                            Button(intent: MarkTaskDoneIntent(taskID: t.id)) {
                                Image(systemName: "checkmark.circle.fill")
                                    .imageScale(.medium)
                                    .foregroundStyle(.gray)
                                    .accessibilityLabel("Mark as done")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .containerBackground(.background, for: .widget)
    }

    // MARK: - Helpers

    private func isOverdue(_ d: Date) -> Bool {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return d < todayStart
    }

    private func shortDue(_ d: Date) -> String {
        let c = Calendar.current
        let todayStart = c.startOfDay(for: Date())
        if d < todayStart { return "Overdue" }
        if c.isDateInToday(d) { return "Today" }
        if c.isDateInTomorrow(d) { return "Tomorrow" }
        let f = DateFormatter(); f.dateFormat = "EEE d"
        return f.string(from: d)
    }
}

// MARK: - Widget
/// The Pathmate widget: blue progress ring + next three tasks (`kind = WidgetKind.pathmate`).
@main
struct PathmateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.pathmate, provider: Provider()) { entry in
            PathmateWidgetView(entry: entry)
        }
        .configurationDisplayName("Pathmate Planner")
        .description("Today’s progress and your next 3 tasks.")
        .supportedFamilies([.systemMedium])
    }
}
