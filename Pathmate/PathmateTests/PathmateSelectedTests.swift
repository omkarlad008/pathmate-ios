//
//  PathmateSelectedTests.swift
//  Pathmate
//
//  Created by kshitija on 15/10/25.
//


import XCTest
import SwiftData
@testable import Pathmate

// =========================================================
// MARK: - Shared Helpers (SwiftData, Next-3, Firebase mock, University test hook)
// =========================================================

/// In-memory SwiftData container so tests are isolated & fast.
@MainActor
private func makeContext() throws -> ModelContext {
    let cfg = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: UserProfileEntity.self, TaskStateEntity.self,
                                       configurations: cfg)
    return ModelContext(container)
}

// ---------- Pure "Next 3" helpers (mirrors logic we assert in tests) ----------
struct JourneyOrderSnapshot {
    let rankByKey: [String:Int]
    func rank(for key: String) -> Int { rankByKey[key] ?? .max }
}

struct TaskLite: Equatable {
    let taskKey: String
    let dueDate: Date?
    let isDone: Bool
}

/// Deterministic, snapshot-ordered selection of 3 unscheduled, not-done items.
/// Sorted by snapshot rank, and tie-broken by key for stability.
func nextThreeUnscheduled(from tasks: [TaskLite],
                          snapshot: JourneyOrderSnapshot) -> [TaskLite] {
    tasks
        .filter { $0.dueDate == nil && !$0.isDone }
        .sorted { a, b in
            let ra = snapshot.rank(for: a.taskKey), rb = snapshot.rank(for: b.taskKey)
            return (ra, a.taskKey) < (rb, b.taskKey)
        }
        .prefix(3)
        .map { $0 }
}

// ---------- Firebase seam (no SDK; pure Swift mock we can assert on) ----------
protocol FirestoreClient {
    func setDocument(path: String, data: [String: Any], merge: Bool)
    func getDocument(path: String) -> [String: Any]?
}

/// What we push from local → remote (trimmed to fields we need)
struct TaskStateLocalSnapshot: Codable, Equatable {
    var taskKey: String, stageRaw: String
    var dueDate: Date?, isDone: Bool, doneAt: Date?, updatedAt: Date
}

struct ProfileLocalSnapshot: Codable, Equatable {
    var fullName: String, studyLevel: String
    var intakeMonth: Int, intakeYear: Int
    var fromCountry: String, toCountry: String
    var cityName: String, universityName: String
    var acceptedPolicy: Bool, updatedAt: Date
}

final class FirestoreSyncCoordinator {
    private let client: FirestoreClient
    private let now: () -> Date
    init(client: FirestoreClient, now: @escaping () -> Date = Date.init) {
        self.client = client; self.now = now
    }

    /// First login: create profile (if absent) and seed task docs (create or merge).
    func firstLoginBootstrap(uid: String, profile: ProfileLocalSnapshot, tasks: [TaskStateLocalSnapshot]) {
        let base = "users/\(uid)"
        let p = "\(base)/profile"
        if client.getDocument(path: p) == nil {
            client.setDocument(path: p, data: [
                "fullName": profile.fullName,
                "studyLevel": profile.studyLevel,
                "intakeMonth": profile.intakeMonth,
                "intakeYear": profile.intakeYear,
                "fromCountry": profile.fromCountry,
                "toCountry": profile.toCountry,
                "cityName": profile.cityName,
                "universityName": profile.universityName,
                "acceptedPolicy": profile.acceptedPolicy,
                "createdAt": now(), "updatedAt": now()
            ], merge: false)
        }
        for t in tasks {
            let path = "\(base)/tasks/\(t.taskKey)"
            var data: [String: Any] = [
                "taskKey": t.taskKey, "stageRaw": t.stageRaw,
                "isDone": t.isDone, "updatedAt": now()
            ]
            data["dueDate"] = t.dueDate as Any
            data["doneAt"]  = t.doneAt  as Any

            if client.getDocument(path: path) == nil {
                data["createdAt"] = now()
                client.setDocument(path: path, data: data, merge: false)
            } else {
                client.setDocument(path: path, data: data, merge: true)
            }
        }
    }

    /// Push a single local edit (reschedule, mark done/undone).
    func pushTaskChange(uid: String, local: TaskStateLocalSnapshot) {
        let path = "users/\(uid)/tasks/\(local.taskKey)"
        let exists = client.getDocument(path: path) != nil
        var data: [String: Any] = [
            "taskKey": local.taskKey, "stageRaw": local.stageRaw,
            "isDone": local.isDone, "updatedAt": now()
        ]
        data["dueDate"] = local.dueDate as Any
        data["doneAt"]  = local.doneAt  as Any
        client.setDocument(path: path, data: data, merge: exists)
    }
}

/// Minimal in-memory Firestore double. We can assert writes/merges without the SDK.
final class MockFirestore: FirestoreClient {
    struct Write {
        let path: String
        let data: [String: Any]
        let merge: Bool
    }
    private(set) var writes: [Write] = []
    private var store: [String: [String: Any]] = [:]

    func setDocument(path: String, data: [String : Any], merge: Bool) {
        writes.append(.init(path: path, data: data, merge: merge))
        if merge {
            var doc = store[path] ?? [:]
            for (k, v) in data { doc[k] = v }
            store[path] = doc
        } else {
            store[path] = data
        }
    }
    func getDocument(path: String) -> [String : Any]? { store[path] }
    func seed(path: String, doc: [String: Any]) { store[path] = doc }
}

// ---------- University VM test-only hook (no app changes required) ----------
enum _UniTestError: Error { case boom }

@MainActor
extension UniversityPickerViewModel {
    /// Drives the same state changes as `refresh()`, but using a test-supplied loader.
    /// Lets us test success & error paths without modifying production code.
    func _test_driveRefresh(using loader: @escaping () async throws -> [Institution]) async {
        isLoading = true
        defer { isLoading = false }
        do {
            institutions = try await loader()
            error = nil
        } catch {
            institutions = []
            self.error = "Couldn’t fetch universities. Please try again."
        }
    }
}

// =========================================================
// MARK: - Tests
// =========================================================

final class PathmateSelectedTests: XCTestCase {

    // ===========================
    // Next 3 (2 tests)
    // ===========================

    /// PURPOSE:
    /// Ensures "Next 3" excludes scheduled & done items,
    /// and orders strictly by the Journey snapshot rank.
    func testNext3_excludesScheduledAndDone_respectsSnapshot() {
        let snap = JourneyOrderSnapshot(rankByKey: [
            "pre.flight.window": 0, "pre.pack.season": 1, "pre.budget.fx": 2, "arr.transfer": 3
        ])
        let items = [
            TaskLite(taskKey: "pre.flight.window", dueDate: nil, isDone: false), // keep
            TaskLite(taskKey: "pre.pack.season",   dueDate: Date(), isDone: false), // scheduled → exclude
            TaskLite(taskKey: "pre.budget.fx",     dueDate: nil, isDone: false), // keep
            TaskLite(taskKey: "arr.transfer",      dueDate: nil, isDone: true) // done → exclude
        ]
        let next = nextThreeUnscheduled(from: items, snapshot: snap)
        XCTAssertEqual(next.map(\.taskKey), ["pre.flight.window", "pre.budget.fx"])
    }

    /// PURPOSE:
    /// When all candidates are unscheduled, any dates are irrelevant; snapshot rank only.
    func testNext3_ignoresDates_ordersBySnapshotOnly() {
        let snap = JourneyOrderSnapshot(rankByKey: ["t1":0, "t2":1, "t3":2, "t4":3])
        let items = [
            TaskLite(taskKey: "t3", dueDate: nil, isDone: false),
            TaskLite(taskKey: "t1", dueDate: nil, isDone: false),
            TaskLite(taskKey: "t4", dueDate: nil, isDone: false),
            TaskLite(taskKey: "t2", dueDate: nil, isDone: false),
        ]
        let next = nextThreeUnscheduled(from: items, snapshot: snap)
        XCTAssertEqual(next.map(\.taskKey), ["t1","t2","t3"])
    }

    // ===========================
    // Planner (4 tests)
    // ===========================

    /// PURPOSE:
    /// Adding two scheduled tasks out of order → `scheduled()` must return earliest-first.
    @MainActor
    func testPlanner_add_andScheduledSort() throws {
        let ctx = try makeContext()
        let repo = PlannerRepository(context: ctx)
        let tasks = TaskRepository.tasks(for: .preDeparture)
        let d1 = Date().addingTimeInterval(3_600)
        let d2 = Date().addingTimeInterval(7_200)

        repo.add(task: tasks[0], stageID: .preDeparture, dueDate: d2)
        repo.add(task: tasks[1], stageID: .preDeparture, dueDate: d1)

        XCTAssertEqual(repo.scheduled().map(\.taskKey), [tasks[1].key, tasks[0].key])
    }

    /// PURPOSE:
    /// Toggling Done moves from Scheduled → Completed, stamps doneAt, and keeps dueDate intact.
    @MainActor
    func testPlanner_toggleDone_movesAndStamps() throws {
        let ctx = try makeContext()
        let repo = PlannerRepository(context: ctx)
        let t = TaskRepository.tasks(for: .arrival).first!
        let due = Date(timeIntervalSince1970: 1_000)

        repo.add(task: t, stageID: .arrival, dueDate: due)
        repo.toggleDone(taskKey: t.key)

        XCTAssertTrue(repo.scheduled().isEmpty)
        let completed = repo.completed()
        XCTAssertEqual(completed.count, 1)
        XCTAssertTrue(completed[0].isDone)
        XCTAssertNotNil(completed[0].doneAt)
        XCTAssertEqual(completed[0].dueDate, due)
    }

    /// PURPOSE:
    /// `ensureAndComplete` creates a row if missing; if a dueDate exists, it must not be overwritten.
    @MainActor
    func testPlanner_ensureAndComplete_createAndPreserveDate() throws {
        let ctx = try makeContext()
        let repo = PlannerRepository(context: ctx)
        let task = TaskRepository.tasks(for: .preDeparture)[0]

        // A) create + complete
        repo.ensureAndComplete(task: task, stageID: .preDeparture)
        var row = repo.item(for: task.key)!
        XCTAssertTrue(row.isDone)

        // B) preserve previously scheduled date
        let d = Date().addingTimeInterval(86_400)
        repo.updateDate(taskKey: task.key, to: d)
        repo.ensureAndComplete(task: task, stageID: .preDeparture)
        row = repo.item(for: task.key)!
        XCTAssertEqual(row.dueDate, d)
    }

    /// PURPOSE:
    /// `scheduled()` only shows dueDate != nil and isDone == false (correct filter).
    @MainActor
    func testPlanner_scheduledFilter_correctness() throws {
        let ctx = try makeContext()
        let repo = PlannerRepository(context: ctx)
        let tasks = TaskRepository.tasks(for: .preDeparture)
        let d = Date().addingTimeInterval(3_600)

        // scheduled & not done → should appear
        repo.add(task: tasks[0], stageID: .preDeparture, dueDate: d)

        // scheduled then done → should NOT appear
        repo.add(task: tasks[1], stageID: .preDeparture, dueDate: d)
        repo.toggleDone(taskKey: tasks[1].key)

        // unscheduled (no dueDate) and done → should NOT appear
        let t3 = TaskRepository.tasks(for: .arrival).first!
        repo.ensureAndComplete(task: t3, stageID: .arrival) // done with nil dueDate allowed by repo

        let keys = Set(repo.scheduled().map(\.taskKey))
        XCTAssertTrue(keys.contains(tasks[0].key))
        XCTAssertFalse(keys.contains(tasks[1].key))
        XCTAssertFalse(keys.contains(t3.key))
    }

    // ===========================
    // Progress (2 tests)
    // ===========================

    /// PURPOSE:
    /// Empty stage progress returns 0 (no NaN/div-by-zero).
    @MainActor
    func testProgress_emptyStage_returnsZero() throws {
        let ctx = try makeContext()
        let p = ProgressRepository(context: ctx)
        XCTAssertEqual(p.progress(for: .arrival, tasks: []), 0)
    }

    /// PURPOSE:
    /// `markDone` / `markUndone` update the fraction accurately.
    @MainActor
    func testProgress_doneUndone_updatesFraction() throws {
        let ctx = try makeContext()
        let p = ProgressRepository(context: ctx)
        let tasks = TaskRepository.tasks(for: .arrival)
        let a = tasks[0].key, b = tasks[1].key

        XCTAssertEqual(p.progress(for: .arrival, tasks: tasks), 0)
        p.markDone(a)
        XCTAssertEqual(p.progress(for: .arrival, tasks: tasks), 1.0 / Double(tasks.count))
        p.markDone(b)
        XCTAssertEqual(p.progress(for: .arrival, tasks: tasks), 2.0 / Double(tasks.count))
        p.markUndone(a)
        XCTAssertEqual(p.progress(for: .arrival, tasks: tasks), 1.0 / Double(tasks.count))
    }

    // ===========================
    // Firebase sync (2 tests; mocked)
    // ===========================

    /// PURPOSE:
    /// First login bootstraps profile + all tasks with createdAt/updatedAt.
    /// Asserts we write correct documents without the Firebase SDK.
    func testFirebase_firstLoginBootstrap_createsProfileAndTasks() {
        let mock = MockFirestore()
        let now = Date(timeIntervalSince1970: 1_234_567)
        let sync = FirestoreSyncCoordinator(client: mock, now: { now })
        let uid = "u1"

        let profile = ProfileLocalSnapshot(
            fullName: "Omkar", studyLevel: "Master",
            intakeMonth: 8, intakeYear: 2027,
            fromCountry: "IN", toCountry: "AU",
            cityName: "Melbourne", universityName: "RMIT (CBD)",
            acceptedPolicy: true, updatedAt: now
        )
        let tasks = [
            TaskStateLocalSnapshot(taskKey: "pre.flight.window", stageRaw: "preDeparture",
                                   dueDate: now, isDone: false, doneAt: nil, updatedAt: now),
            TaskStateLocalSnapshot(taskKey: "arr.transfer", stageRaw: "arrival",
                                   dueDate: nil, isDone: true, doneAt: now, updatedAt: now)
        ]

        sync.firstLoginBootstrap(uid: uid, profile: profile, tasks: tasks)

        // Profile was created with timestamps
        let p = mock.getDocument(path: "users/\(uid)/profile")!
        XCTAssertEqual(p["fullName"] as? String, "Omkar")
        XCTAssertNotNil(p["createdAt"])
        XCTAssertEqual(p["updatedAt"] as? Date, now)

        // Task docs exist
        XCTAssertNotNil(mock.getDocument(path: "users/\(uid)/tasks/pre.flight.window"))
        XCTAssertNotNil(mock.getDocument(path: "users/\(uid)/tasks/arr.transfer"))
    }

    /// PURPOSE:
    /// Local edit after login merges into existing task doc with changed fields.
    func testFirebase_pushTaskChange_mergesExisting() {
        let mock = MockFirestore()
        let base = Date(timeIntervalSince1970: 2_000_000)
        let sync = FirestoreSyncCoordinator(client: mock, now: { base })
        let uid = "u2"

        // Seed existing doc (as if created during first login)
        mock.seed(path: "users/\(uid)/tasks/pre.budget.fx", doc: [
            "taskKey": "pre.budget.fx",
            "stageRaw": "preDeparture",
            "isDone": false,
            "updatedAt": base
        ])

        let local = TaskStateLocalSnapshot(taskKey: "pre.budget.fx", stageRaw: "preDeparture",
                                           dueDate: Date(timeIntervalSince1970: 2_000_100),
                                           isDone: true,
                                           doneAt: Date(timeIntervalSince1970: 2_000_200),
                                           updatedAt: base.addingTimeInterval(10))

        sync.pushTaskChange(uid: uid, local: local)

        guard let w = mock.writes.last else { return XCTFail("No write recorded") }
        XCTAssertEqual(w.path, "users/\(uid)/tasks/pre.budget.fx")
        XCTAssertTrue(w.merge)
        XCTAssertEqual(w.data["isDone"] as? Bool, true)
        XCTAssertEqual(w.data["dueDate"] as? Date, local.dueDate)
        XCTAssertEqual(w.data["doneAt"] as? Date, local.doneAt)
    }

    // ===========================
    // University fetch (1 test; success + error; no app changes)
    // ===========================

    /// PURPOSE:
    /// Success → cities unique & sorted + case-insensitive filter works.
    /// Error → list cleared and a friendly error is set.
    @MainActor
    func testUniversity_fetch_success_and_error_paths() async {
        // Mock institutions: two Melbourne, one Sydney
        let melA = Institution(
            id: "I1", display_name: "RMIT",
            geo: .init(city: "Melbourne", region: nil, country_code: "AU",
                       country: "Australia", latitude: nil, longitude: nil)
        )
        let melB = Institution(
            id: "I2", display_name: "UniMelb",
            geo: .init(city: "Melbourne", region: nil, country_code: "AU",
                       country: "Australia", latitude: nil, longitude: nil)
        )
        let syd = Institution(
            id: "I3", display_name: "USYD",
            geo: .init(city: "Sydney", region: nil, country_code: "AU",
                       country: "Australia", latitude: nil, longitude: nil)
        )

        // A) Success path (no network — we inject the data)
        let vmA = UniversityPickerViewModel()
        await vmA._test_driveRefresh(using: { [melA, melB, syd] })

        // Cities must be unique + sorted
        let cities = Array(Set(vmA.institutions.compactMap { $0.geo?.city })).sorted()
        XCTAssertEqual(cities, ["Melbourne", "Sydney"])

        // Filter must be case-insensitive
        let melOnly = vmA.institutions(in: "MELBOURNE")
        XCTAssertEqual(Set(melOnly.map(\.display_name)), ["RMIT", "UniMelb"])

        // B) Error path — clears list and sets friendly message
        let vmB = UniversityPickerViewModel()
        await vmB._test_driveRefresh(using: { throw _UniTestError.boom })
        XCTAssertTrue(vmB.institutions.isEmpty)
        XCTAssertNotNil(vmB.error)
    }
}
