//
//  TimelineCanvasView.swift
//  Pathmate
//
//  Created by Omkar Lad on 16/10/2025.
//

import SwiftUI

struct TimelineCanvasView: View {
    let items: [TimelineTaskItem]
    let config: TimelineConfig
    let onSchedule: (String, Date) -> Void
    let onMarkDone: (String) -> Void
    let onSnooze: (String, DateComponents) -> Void
    let onOpenDetail: (String) -> Void

    @State private var dayWidth: CGFloat = 280
    @GestureState private var zoom: CGFloat = 1.0

    private let hourHeight: CGFloat = 56
    private let headerHeight: CGFloat = 36

    @State private var now: Date = Date()         

    init(
        items: [TimelineTaskItem],
        config: TimelineConfig = TimelineConfig(),
        onSchedule: @escaping (String, Date) -> Void,
        onMarkDone: @escaping (String) -> Void,
        onSnooze: @escaping (String, DateComponents) -> Void,
        onOpenDetail: @escaping (String) -> Void
    ) {
        self.items = items
        self.config = config
        self.onSchedule = onSchedule
        self.onMarkDone = onMarkDone
        self.onSnooze = onSnooze
        self.onOpenDetail = onOpenDetail
    }

    private var startOfWindow: Date {
        Calendar.current.date(
            byAdding: .day,
            value: config.startOffsetDays,
            to: Calendar.current.startOfDay(for: Date())
        )!
    }
    private var days: [Date] {
        (0..<config.dayRange).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: startOfWindow)
        }
    }
    private var todayStart: Date { Calendar.current.startOfDay(for: now) }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 8) {
                // Go to Today button
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut) {
                            proxy.scrollTo(todayStart, anchor: .center)
                        }
                    } label: {
                        Label("Today", systemImage: "scope")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)

                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    let effectiveDayWidth = max(config.minZoom, min(config.maxZoom, zoom)) * dayWidth
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(days, id: \.self) { day in
                            ZStack(alignment: .topLeading) {
                                grid(for: day, width: effectiveDayWidth)

                                // Overdue shading
                                overdueOverlay(for: day)

                                // Chips for this day
                                ForEach(itemsFor(day: day)) { chip in
                                    chipView(chip, dayWidth: effectiveDayWidth)
                                }

                                // Now line (only for today)
                                if Calendar.current.isDate(day, inSameDayAs: now) {
                                    nowLine(for: now)
                                }
                            }
                            .frame(width: effectiveDayWidth,
                                   height: headerHeight + hourHeight * 24)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            .id(Calendar.current.startOfDay(for: day)) // for scrollTo(today)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .gesture(
                        MagnificationGesture()
                            .updating($zoom) { value, state, _ in state = value }
                    )
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if config.showsNowIndicator {
                nowBadge()
                    .padding(.leading, 20)
                    .padding(.top, 4)
            }
        }
        // Tick the "now" line every minute
        .onReceive(
            Timer.publish(every: 60, on: .main, in: .common).autoconnect()
        ) { tick in
            now = tick
        }
    }

    // MARK: - Grid

    @ViewBuilder
    private func grid(for day: Date, width: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text(dayLabel(day))
                .font(.headline)
                .padding(.top, 8)
            Divider().padding(.bottom, 4)
            ForEach(0..<24, id: \.self) { h in
                HStack(spacing: 0) {
                    Text(String(format: "%02d:00", h))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                        .padding(.trailing, 6)
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 0.5)
                }
                .frame(height: hourHeight)
            }
        }
    }

    private func dayLabel(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEE d MMM"
        return df.string(from: d)
    }

    // MARK: - Chips

    @ViewBuilder
    private func chipView(_ item: TimelineTaskItem, dayWidth: CGFloat) -> some View {
        let start = Calendar.current.dateComponents([.hour, .minute], from: item.scheduled)
        let top = (CGFloat(start.hour ?? 0) + CGFloat(start.minute ?? 0)/60.0) * hourHeight

        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(item.tint.color.opacity(item.isDone ? 0.35 : 0.9))
            .overlay(
                HStack(spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.footnote)
                        .opacity(0.8)
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(timeLabel(item.scheduled))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            )
            .frame(width: dayWidth - 20,
                   height: max(36, CGFloat(item.duration/3600) * hourHeight - 8))
            // NOTE: add headerHeight so chips don't overlap the header
            .position(x: dayWidth/2, y: headerHeight + top + 18)
            .shadow(radius: 2, y: 1)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture { onOpenDetail(item.id) }
            .gesture(longPressThenDrag(for: item, dayWidth: dayWidth))
    }

    private func timeLabel(_ d: Date) -> String {
        let df = DateFormatter()
        df.timeStyle = .short
        return df.string(from: d)
    }

    private func itemsFor(day: Date) -> [TimelineTaskItem] {
        items.filter { Calendar.current.isDate($0.scheduled, inSameDayAs: day) }
    }

    // MARK: - Gestures

    private func longPressThenDrag(for item: TimelineTaskItem, dayWidth: CGFloat) -> some Gesture {
        let long = LongPressGesture(minimumDuration: 0.12)
        let drag = DragGesture(minimumDistance: 6)

        return long.sequenced(before: drag)
            .onEnded { value in
                switch value {
                case .second(true, let drag?):
                    let dx = drag.translation.width
                    let dy = drag.translation.height

                    // Quick actions via vertical “flicks”
                    if dy < -90 {
                        onMarkDone(item.id)
                        return
                    } else if dy > 90 {
                        onSnooze(item.id, DateComponents(day: 1))
                        return
                    }

                    // Cross-day move by horizontal distance
                    let dayDelta = Int((dx / dayWidth).rounded())

                    // Vertical move inside the day (minutes)
                    let minutesDelta = Int(dy / hourHeight * 60.0)

                    var newDate = Calendar.current.date(byAdding: .day, value: dayDelta, to: item.scheduled) ?? item.scheduled
                    newDate = Calendar.current.date(byAdding: .minute, value: minutesDelta, to: newDate) ?? newDate

                    // Snap to nearest slot (e.g. 30 min)
                    newDate = newDate.quantized(to: config.slotMinutes)

                    onSchedule(item.id, newDate)

                default:
                    break
                }
            }
    }

    // MARK: - Overdue shading

    @ViewBuilder
    private func overdueOverlay(for day: Date) -> some View {
        let cal = Calendar.current
        if cal.compare(day, to: todayStart, toGranularity: .day) == .orderedAscending {
            // Entire past-day area (hours region only)
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: hourHeight * 24)
                .offset(y: headerHeight)
        } else if cal.isDate(day, inSameDayAs: now) {
            // Today: shade from start-of-day up to "now"
            let comps = cal.dateComponents([.hour, .minute], from: now)
            let y = (CGFloat(comps.hour ?? 0) + CGFloat(comps.minute ?? 0)/60.0) * hourHeight
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: y)
                .offset(y: headerHeight)
        }
    }

    // MARK: - Now line

    @ViewBuilder
    private func nowLine(for date: Date) -> some View {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let y = headerHeight + (CGFloat(comps.hour ?? 0) + CGFloat(comps.minute ?? 0)/60.0) * hourHeight
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.accentColor.opacity(0.7))
                .frame(height: 2)
                .offset(y: y)
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)
                .offset(x: 8, y: y - 3)
        }
    }

    // MARK: - Now badge

    @ViewBuilder
    private func nowBadge() -> some View {
        HStack(spacing: 6) {
            Circle().frame(width: 6, height: 6)
            Text("Now").font(.caption2.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - Helpers

private extension Date {
    func clampedToDayOf(_ reference: Date) -> Date {
        let comps = Calendar.current.dateComponents([.hour,.minute], from: self)
        var base = Calendar.current.startOfDay(for: reference)
        base = Calendar.current.date(byAdding: comps, to: base) ?? reference
        return base
    }
}

private extension Int {
    /// Rounds `x` to nearest multiple of `m` (e.g. 37 → 30 if m=30, 44 → 45)
    static func roundedToNearest(_ x: Int, multiple m: Int) -> Int {
        guard m > 0 else { return x }
        let r = x % m
        let down = x - r
        let up = down + m
        return (x - down) < (up - x) ? down : up
    }
}

private extension Date {
    /// Quantize time-of-day to nearest N-minute slot, preserving the date.
    func quantized(to slotMinutes: Int) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: self)
        let total = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let snapped = Int.roundedToNearest(total, multiple: slotMinutes)
        let h = snapped / 60, m = snapped % 60
        return cal.date(bySettingHour: h, minute: m, second: 0, of: self) ?? self
    }
}
