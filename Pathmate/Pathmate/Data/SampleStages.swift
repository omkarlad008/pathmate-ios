//
//  SampleStages.swift
//  Pathmate
//
//  Created by Omkar Lad on 27/8/2025.
//

// MARK: - Imports
// Uses only Foundation so the data can be reused in tests or previews
// without pulling in SwiftUI.
import Foundation

/// **SampleStages**
///
/// Static sample data for the Journey/Stages UI used in previews.
/// Each element describes a ``Stage`` with a title,
/// subtitle, SF Symbol name in `symbol`, a `tint` token, and an approximate
/// completion `progress` in the `0.0...1.0` range.
///
/// Stages included (in display order):
/// 1. Pre-departure
/// 2. Arrival
/// 3. University
/// 4. Work & Compliance
/// 5. Life & Balance
///
/// - Important: `progress` is a fraction in `0.0...1.0`.
/// - Note: `symbol` values are SF Symbols; resolve tint via ``Tint/color`` in views.
/// - SeeAlso: <doc:DataModel>, ``JourneyView``, ``StageRow``
///
/// ### Example
/// ```swift
/// #Preview {
///   List(sampleStages) { stage in
///     StageRow(icon: stage.symbol,
///              tint: stage.tint.color,
///              title: stage.title,
///              subtitle: stage.subtitle,
///              progress: stage.progress)
///   }
/// }
/// ```
let sampleStages: [Stage] = [
    Stage(id: .preDeparture,
          title: "Pre-departure",
          subtitle: "Tasks before leaving India",
          symbol: "airplane",
          tint: .blue,
          progress: 0.60),

    Stage(id: .arrival,
          title: "Arrival",
          subtitle: "First week after landing",
          symbol: "mappin.and.ellipse",
          tint: .purple,
          progress: 0.20),

    Stage(id: .university,
          title: "University",
          subtitle: "Orientation, ID, systems setup",
          symbol: "graduationcap.fill",
          tint: .indigo,
          progress: 0.00),

    Stage(id: .workCompliance,
          title: "Work & Compliance",
          subtitle: "Jobs, TFN, Fair Work rules",
          symbol: "briefcase.fill",
          tint: .orange,
          progress: 0.00),

    Stage(id: .lifeBalance,
          title: "Life & Balance",
          subtitle: "Groceries, transport, wellbeing",
          symbol: "heart.fill",
          tint: .green,
          progress: 0.00),
]
