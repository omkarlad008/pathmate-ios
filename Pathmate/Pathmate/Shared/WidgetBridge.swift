import Foundation
/// Tiny persistence bridge for the widget snapshot using the App Group.
///
/// Reads/writes a JSON-encoded ``WidgetSnapshot`` to:
/// 1) `UserDefaults(suiteName:)` (fast path), and
/// 2) a file `widget_snapshot.json` inside the shared container (fallback).
///
/// - SeeAlso: ``AppGroup``, ``WidgetSnapshot``
enum WidgetBridge {
    /// UserDefaults key for the current snapshot version.
    private static let key = "widget.snapshot.v1"
    /// App Group `UserDefaults` used for the fast-path read/write.
    private static var box: UserDefaults? {
        UserDefaults(suiteName: AppGroup.id)
    }
    /// Fallback file location for snapshot persistence in the shared container.
    private static var fileURL: URL? = {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id)?
            .appendingPathComponent("widget_snapshot.json")
    }()
    /// Load the last published snapshot from App Group storage.
    ///
    /// - Returns: The decoded ``WidgetSnapshot`` or `nil` if not present.
    static func read() -> WidgetSnapshot? {
        // 1) Fast path: App Group UserDefaults
        if let data = box?.data(forKey: key),
           let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) {
            return snap
        }
        // 2) Fallback: file in the shared container
        if let url = fileURL,
           let data = try? Data(contentsOf: url),
           let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) {
            return snap
        }
        return nil
    }
    /// Persist a snapshot to both App Group `UserDefaults` and the fallback file.
    ///
    /// - Parameter snapshot: The snapshot to store.
    static func write(_ snapshot: WidgetSnapshot) {
        let data = try? JSONEncoder().encode(snapshot)
        box?.set(data, forKey: key)
        if let url = fileURL, let data {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Locally toggle a task’s `isDone` inside the snapshot’s `next` array.
    ///
    /// - Note: Used for instant UI feedback; the real source of truth is SwiftData.
    static func setDone(taskID: String, done: Bool) {
        guard var s = read() else { return }
        if let i = s.next.firstIndex(where: { $0.id == taskID }) {
            let t = s.next[i]
            s.next[i] = .init(id: t.id, title: t.title, scheduledDate: t.scheduledDate, isDone: done, stageName: t.stageName)
        }
        write(s)
    }
    /// Locally update a task’s `scheduledDate`, re-sort, and clamp `next` to top 3.
    ///
    /// - Note: The full recompute still happens in the publisher on app-side.
    static func reschedule(taskID: String, to newDate: Date) {
        guard var s = read() else { return }
        if let i = s.next.firstIndex(where: { $0.id == taskID }) {
            let t = s.next[i]
            s.next[i] = .init(id: t.id, title: t.title, scheduledDate: newDate, isDone: t.isDone, stageName: t.stageName)
            s.next.sort { $0.scheduledDate < $1.scheduledDate }
            s.next = Array(s.next.prefix(3))
        }
        write(s)
    }
}
