//
//  TaskRepository.swift
//  Pathmate
//
//  Created by Omkar Lad on 27/8/2025.
//

// MARK: - Imports
// Foundation is sufficient because this module only returns data structures.
// No SwiftUI import is required here.
import Foundation

/// **TaskRepository**
///
/// Static, in-memory source of ``ChecklistTask`` items grouped by ``StageID``.
/// Used by the Checklist page and Task Detail.
///
/// The repository exposes a single query method that returns the tasks for a
/// given journey stage. Each task includes a stable ``ChecklistTask/key``,
/// user-visible `title` and `subtitle`, and a ``TaskDetail`` structure.
///
/// - Important: ``ChecklistTask/key`` values act as stable identifiers (for deep-links
///   or persistence).
/// - Note: Links included in details are placeholders and do not perform network calls.
/// - SeeAlso: ``TaskService``, ``StaticTaskService``, ``ChecklistTask``, ``TaskDetail``, ``StageID``
enum TaskRepository {
    
    /// Returns all checklist tasks for the specified journey stage.
    ///
    /// The order of the returned array is the recommended display order in UI.
    /// Content is intentionally concise to fit compact widths.
    ///
    /// - Parameters:
    ///   - stage: The journey stage whose tasks should be returned.
    /// - Returns: An array of ``ChecklistTask`` describing actionable items.
    ///
    /// ### Example
    /// ```swift
    /// let arrivalTasks = TaskRepository.tasks(for: .arrival)
    /// // Bind to a List in SwiftUI:
    /// // List(arrivalTasks) { task in ... }
    /// ```
    ///
    /// - Note: This function performs no I/O; it simply returns static data.
    static func tasks(for stage: StageID) -> [ChecklistTask] {
        
        // MARK: - Stage groupings
        // Each case returns the tasks for one journey stage.
        // Copy is user-visible; kept it short and scannable.
        switch stage {
            
        // Pre-departure: planning tasks before leaving your home country.
        // Includes flight research, budget planning, and seasonal packing.
        case .preDeparture:
            return [
                // Key pattern: "pre.flight.window" — stable identifier for this task.
                ChecklistTask(
                    key: "pre.flight.window",
                    title: "Find cheapest flight window",
                    subtitle: "Compare prices for your intake month",
                    detail: TaskDetail(
                        what: "Search for flights across your intake month.",
                        why: "You’ll save money and pick a convenient arrival date.",
                        steps: [
                            "Open a flight search site with 'whole month' view.",
                            "Pick your origin city in India and destination in Australia.",
                            "Compare weekdays vs weekends; note baggage rules."
                        ],
                        links: [
                            ResourceLink(label: "Skyscanner Month View", url: "https://www.skyscanner.com.au"),
                            ResourceLink(label: "Airline Baggage Info (sample)", url: "https://www.qantas.com/")
                        ]
                    )
                ),
                // Budgeting + FX planning; detail includes simple step breakdown and a link.
                ChecklistTask(
                    key: "pre.budget.fx",
                    title: "Budget INR ↔ AUD",
                    subtitle: "Know fees & living costs",
                    detail: TaskDetail(
                        what: "Estimate tuition, rent and monthly expenses in AUD and INR.",
                        why: "Prevents shortfalls and helps choose the right money transfer.",
                        steps: [
                            "List tuition, rent, transport, food and utilities.",
                            "Convert totals using a baseline FX rate (dummy for now).",
                            "Plan opening balance and monthly allowance."
                        ],
                        links: [
                            ResourceLink(label: "Study in Australia cost guide", url: "https://www.studyaustralia.gov.au/")
                        ]
                    )
                ),
                // Season-aware packing guidance with lightweight, actionable steps.
                ChecklistTask(
                    key: "pre.pack.season",
                    title: "Pack for the season",
                    subtitle: "Weather-based packing tips",
                    detail: TaskDetail(
                        what: "Pack clothes suited to the city and season you arrive in.",
                        why: "Reduces extra spending after landing.",
                        steps: [
                            "Check average temp of your destination for arrival month.",
                            "Pack layers, a light jacket, and comfortable shoes.",
                            "Keep documents and meds in carry-on."
                        ],
                        links: []
                    )
                )
            ]
        // Arrival: tasks for the first days after landing (transfer, SIM, first remit).
        case .arrival:
            return [
                ChecklistTask(
                    key: "arr.transfer",
                    title: "Airport → accommodation transfer",
                    subtitle: "Best routes & time",
                    detail: TaskDetail(
                        what: "Pick a transport option from airport to your temporary stay.",
                        why: "Arrive safely with minimal cost and confusion.",
                        steps: [
                            "Check airport train/bus availability.",
                            "Price rideshare vs public transport.",
                            "Share ETA with a friend."
                        ],
                        links: []
                    )
                ),
                ChecklistTask(
                    key: "arr.sim",
                    title: "Buy a local SIM",
                    subtitle: "Coverage near campus",
                    detail: TaskDetail(
                        what: "Get an Aussie SIM with good campus coverage.",
                        why: "You’ll need it for bank/TFN OTP and maps.",
                        steps: [
                            "Compare starter packs at airport or nearby stores.",
                            "Activate with passport/visa details.",
                            "Test data + call quality near your stay."
                        ],
                        links: []
                    )
                ),
                ChecklistTask(
                    key: "arr.first.remit",
                    title: "First bank transfer estimate",
                    subtitle: "INR → AUD rate",
                    detail: TaskDetail(
                        what: "Send initial funds to your Australian account.",
                        why: "Covers first month rent and settling costs.",
                        steps: [
                            "Note your bank account number & BSB.",
                            "Compare remittance options.",
                            "Transfer a small test amount first."
                        ],
                        links: []
                    )
                )
            ]
        // University: campus logistics and checks (transport, essentials, CRICOS).
        case .university:
            return [
                ChecklistTask(
                    key: "uni.transport",
                    title: "Get to campus easily",
                    subtitle: "Bus/tram/train routes",
                    detail: TaskDetail(
                        what: "Identify the best public transport route.",
                        why: "Saves time and money during semester.",
                        steps: [
                            "Search your home → campus route.",
                            "Note off-peak timings.",
                            "Save stops as favourites."
                        ],
                        links: []
                    )
                ),
                ChecklistTask(
                    key: "uni.essentials",
                    title: "Campus essentials map",
                    subtitle: "Library, printing, cafe",
                    detail: TaskDetail(
                        what: "Find the key facilities on campus.",
                        why: "Avoids scramble during first week.",
                        steps: [
                            "Open campus map.",
                            "Locate library, student hub, printing.",
                            "Bookmark emergency facilities."
                        ],
                        links: []
                    )
                ),
                ChecklistTask(
                    key: "uni.cricos",
                    title: "CRICOS check",
                    subtitle: "Provider authorisation",
                    detail: TaskDetail(
                        what: "Verify your provider on CRICOS (dummy step for now).",
                        why: "Confirms legit provider and course.",
                        steps: [
                            "Search CRICOS by provider name.",
                            "Check course code and duration.",
                            "Save reference number."
                        ],
                        links: []
                    )
                )
            ]
        // Work & compliance: job search basics and simple compliance checks.
        case .workCompliance:
            return [
                ChecklistTask(
                    key: "work.jobs.nearby",
                    title: "Find part-time jobs nearby",
                    subtitle: "Role + suburb search",
                    detail: TaskDetail(
                        what: "Search jobs in hospitality/retail near your suburb.",
                        why: "Quick income to support living expenses.",
                        steps: [
                            "Search with role keywords + suburb.",
                            "Prepare Aussie-style resume.",
                            "Apply to 3–5 postings."
                        ],
                        links: []
                    )
                ),
                ChecklistTask(
                    key: "work.abn.check",
                    title: "ABN check",
                    subtitle: "Validate before gig work",
                    detail: TaskDetail(
                        what: "Validate ABN (dummy info for now).",
                        why: "Avoid scams and ensure compliance.",
                        steps: [
                            "Ask the business for their ABN.",
                            "Verify against public register.",
                            "Keep a record in your notes."
                        ],
                        links: []
                    )
                ),
                ChecklistTask(
                    key: "work.wage.snap",
                    title: "Wage snapshot",
                    subtitle: "Market pay for your role",
                    detail: TaskDetail(
                        what: "Understand typical hourly rates.",
                        why: "Ensure you’re paid fairly.",
                        steps: [
                            "Check Fair Work guidance.",
                            "Look at recent postings for pay bands.",
                            "Track your hours and payslips."
                        ],
                        links: []
                    )
                )
            ]
        // Life & balance: everyday setup (public transport, weather/AQI, scam awareness).
        case .lifeBalance:
            return [
                ChecklistTask(
                    key: "life.pt.setup",
                    title: "Public transport setup",
                    subtitle: "Nearby stops & departures",
                    detail: TaskDetail(
                        what: "Set up your transport card/app.",
                        why: "Makes daily travel easy and cheaper.",
                        steps: [
                            "Buy and top up your card.",
                            "Add the official transport app.",
                            "Set up student concession if eligible."
                        ],
                        links: []
                    )
                ),
                ChecklistTask(
                    key: "life.weather.aqi",
                    title: "Weather & air quality",
                    subtitle: "Plan clothing/outdoor study",
                    detail: TaskDetail(
                        what: "Check today’s weather & AQI (dummy for now).",
                        why: "Dress right and plan your commute.",
                        steps: [
                            "Check temperature and rain chance.",
                            "Pack an umbrella / sunscreen as needed.",
                            "Note wind chill if cycling."
                        ],
                        links: []
                    )
                ),
                ChecklistTask(
                    key: "life.scam.aware",
                    title: "Scam alerts awareness",
                    subtitle: "Latest rental/job scams",
                    detail: TaskDetail(
                        what: "Learn common scam patterns.",
                        why: "Protects your money and identity.",
                        steps: [
                            "Never pay bond without inspection.",
                            "Avoid jobs asking upfront fees.",
                            "Verify contacts via official sites."
                        ],
                        links: []
                    )
                )
            ]
        }
    }
    
    // MARK: - Lookups for widget/repositories
    
    /// Returns the `ChecklistTask` for a stable key, if any.
    static func task(forKey key: String) -> ChecklistTask? {
        for sid in StageID.allCases {
            if let t = tasks(for: sid).first(where: { $0.key == key }) { return t }
        }
        return nil
    }
    
    /// Returns the owning StageID for a task key, if found.
    static func stageID(forTaskKey key: String) -> StageID? {
        for sid in StageID.allCases {
            if tasks(for: sid).contains(where: { $0.key == key }) { return sid }
        }
        return nil
    }
    
    /// Convenience tuple for widget rows: (title, stage display title)
    static func titleAndStage(for key: String) -> (title: String, stage: String?) {
        guard let task = task(forKey: key),
                let sid  = stageID(forTaskKey: key) else {
            return ("Task", nil)
        }
        return (task.title, sid.displayTitle)
    }
}
