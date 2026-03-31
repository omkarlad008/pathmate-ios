//
//  TimelineUndo.swift
//  Pathmate
//
//  Created by Omkar Lad on 17/10/2025.
//

import Foundation

final class TimelineUndo: ObservableObject {
    struct Event: Identifiable {
        let id = UUID()
        let label: String
        let undo: () -> Void
        let redo: () -> Void
    }

    @Published var lastEvent: Event?

    func push(_ e: Event) { lastEvent = e }
    func undoLast() { lastEvent?.undo(); lastEvent = nil }
    func redoLast() { lastEvent?.redo() }
}
