//
//  TimelineTypes.swift
//  Pathmate
//
//  Created by Omkar Lad on 16/10/2025.
//

import SwiftUI

struct TimelineTaskItem: Identifiable, Hashable {
    let id: String            // taskKey
    var title: String
    var stageID: StageID
    var scheduled: Date       // required for timeline placement
    var duration: TimeInterval = 60 * 60  // default 1h
    var isDone: Bool
    var tint: Tint
}

struct TimelineConfig {
    var startOffsetDays: Int = -1   // show from yesterday by default
    var dayRange: Int = 8           // yesterday + today + next 6 = 8 days
    var slotMinutes: Int = 30
    var showsNowIndicator: Bool = true
    var minZoom: CGFloat = 0.85
    var maxZoom: CGFloat = 1.25
}

