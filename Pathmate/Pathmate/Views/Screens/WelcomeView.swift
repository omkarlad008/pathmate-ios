//
//  WelcomeView.swift
//  Pathmate
//
//  Created by Kshitija on 28/8/2025.
//

import SwiftUI

/// Initializes a `Color` from a hex string in `#RRGGBB` or `#RRGGBBAA` form.
///
/// - Parameter hex: A 6- or 8-digit hex string; leading `#` optional.
/// - Note: Returns `.clear` if the input cannot be parsed.
extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "").uppercased()
        func ch(_ v: UInt64, _ sh: Int) -> Double { Double((v >> sh) & 0xFF) / 255.0 }
        var v: UInt64 = 0; Scanner(string: s).scanHexInt64(&v)
        switch s.count {
        case 6: self = Color(.sRGB, red: ch(v,16), green: ch(v,8), blue: ch(v,0), opacity: 1)
        case 8: self = Color(.sRGB, red: ch(v,24), green: ch(v,16), blue: ch(v,8), opacity: ch(v,0))
        default: self = .clear
        }
    }
}

/// Parameterised geometry for an orthogonal inverted-S rail.
///
/// Tunable insets and elbow positions yield a friendly S-shaped path that the
/// logo chips sit on. Values are expressed as fractions of a given rect.
struct OrthogonalSGeometry {
    var leftInset: CGFloat   = 0.40
    var rightInset: CGFloat  = 0.40
    var topY: CGFloat        = 0.25
    var midY: CGFloat        = 0.60
    var bottomY: CGFloat     = 0.95
    var rightElbowX: CGFloat = 0.60
    var leftElbowX: CGFloat  = 0.40

    /// Anchor points (start, elbows, middle, end) expressed in the given rect’s space.
    ///
    /// - Parameter r: The layout/drawing rectangle.
    /// - Returns: A tuple of five key points used by the shape and layout.
    func points(in r: CGRect) -> (start: CGPoint, elbowR: CGPoint, middle: CGPoint, elbowL: CGPoint, end: CGPoint) {
        let w = r.width, h = r.height
        let xL = r.minX + leftInset  * w
        let xR = r.maxX - rightInset * w
        let xRight = r.minX + rightElbowX * w
        let xLeft  = r.minX + leftElbowX  * w
        let yTop = r.minY + topY    * h
        let yMid = r.minY + midY    * h
        let yBot = r.minY + bottomY * h

        return (
            start:  CGPoint(x: xL,     y: yTop),
            elbowR: CGPoint(x: xRight, y: yTop),
            middle: CGPoint(x: (xLeft + xRight)/2, y: yMid),
            elbowL: CGPoint(x: xLeft,  y: yMid),
            end:    CGPoint(x: xR,     y: yBot)
        )
    }
}
/// Draws the orthogonal inverted-S rail using straight segments derived from geometry.
struct OrthogonalInvertedSShape: Shape {
    /// Geometry parameters that define rail proportions.
    var geom: OrthogonalSGeometry
    /// Builds the rail path from precomputed anchor points within `rect`.
    func path(in rect: CGRect) -> Path {
        let (start, elbowR, _, elbowL, end) = geom.points(in: rect)
        let yMid = geom.midY * rect.height + rect.minY
        var p = Path()
        p.move(to: start)
        p.addLine(to: elbowR)
        p.addLine(to: CGPoint(x: elbowR.x, y: yMid))
        p.addLine(to: CGPoint(x: elbowL.x, y: yMid))
        p.addLine(to: CGPoint(x: elbowL.x, y: geom.bottomY * rect.height + rect.minY))
        p.addLine(to: end)
        return p
    }
}
/// Custom `Layout` that positions milestone chips at the rail’s anchor points.
///
/// The layout is deterministic and provides an intrinsic size so the composed
/// logo scales predictably across containers.
struct OrthogonalSLayout: Layout {
    /// Geometry driving anchor locations.
    /// Size of each milestone chip.
    var geom: OrthogonalSGeometry
    var nodeSize: CGFloat = 44
    /// Intrinsic size hint: uses proposed width (or 320 if nil) and a minimum height of 110.
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 320, height: max(110, proposal.height ?? 110))
    }
    /// Places each subview on its corresponding rail anchor within `bounds`.
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }

        let pts = geom.points(in: bounds)

        let bottomLeft = CGPoint(
            x: bounds.minX + geom.leftElbowX * bounds.width,
            y: bounds.minY + geom.bottomY    * bounds.height
        )

        let anchors: [CGPoint] = [pts.start, pts.elbowR, pts.middle, bottomLeft, pts.end]

        let p = ProposedViewSize(CGSize(width: nodeSize, height: nodeSize))
        for (i, v) in subviews.enumerated() {
            let idx = min(i, anchors.count - 1)
            v.place(at: anchors[idx], anchor: .center, proposal: p)
        }
    }
}
/// Circular chip with tinted icon, subtle ring, and masked background used in the logo.
///
/// - Parameters:
///   - systemName: SF Symbol name.
///   - tint: Foreground and ring color.
///   - size: Square side length in points.
struct MilestoneChip: View {
    let systemName: String
    let tint: Color
    let size: CGFloat
    // Chip layers: mask, tint fill, ring, and SF Symbol.
    var body: some View {
        ZStack {
            Circle().fill(Color(.systemBackground))
            Circle().fill(tint.opacity(0.16))
            Circle().stroke(tint.opacity(0.35), lineWidth: 1)
            Image(systemName: systemName)
                .font(.system(size: max(14, size * 0.42), weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
/// **Welcome & Brand Logo**
///
/// A small brand system:
/// - hex→`Color` helper,
/// - parametric inverted-S rail (``OrthogonalSGeometry`` + ``OrthogonalInvertedSShape``),
/// - custom ``OrthogonalSLayout`` snapping milestone chips to anchors,
/// - composed logo view (this type),
/// - and the ``WelcomeView`` scaffold with primary CTA.
///
/// - SeeAlso: ``WelcomeView``, ``OrthogonalSGeometry``, ``OrthogonalInvertedSShape``, ``OrthogonalSLayout``
struct PathmateOrthogonalSLogo: View {
    private let geom = OrthogonalSGeometry(
        leftInset: 0.40, rightInset: 0.40,
        topY: 0.25, midY: 0.60, bottomY: 0.95,
        rightElbowX: 0.60, leftElbowX: 0.40
    )
    private let nodeSize: CGFloat = 44
    private let railColor = Color(hex: "#F7D046").opacity(0.60)
    private let blueChip   = Color(hex: "#60A5FA")
    private let greenChip  = Color(hex: "#34D399")
    private let orangeChip = Color(hex: "#F59E0B")
    private let pinkChip   = Color(hex: "#FB7185")
    private let purpleChip = Color(hex: "#A78BFA")
    var body: some View {
        ZStack {
            // Draw the rail behind the chips with a friendly amber tint.
            OrthogonalInvertedSShape(geom: geom)
                .stroke(railColor,
                        style: StrokeStyle(lineWidth: 3, lineCap: .square, lineJoin: .miter))
                .allowsHitTesting(false)
            // Lay out the five milestone chips along the rail anchors.
            OrthogonalSLayout(geom: geom, nodeSize: nodeSize) {
                MilestoneChip(systemName: "airplane",              tint: blueChip,   size: nodeSize)
                MilestoneChip(systemName: "checkmark.circle.fill", tint: greenChip,  size: nodeSize)
                MilestoneChip(systemName: "calendar",              tint: orangeChip, size: nodeSize)
                MilestoneChip(systemName: "book.fill",             tint: pinkChip,   size: nodeSize)
                MilestoneChip(systemName: "graduationcap.fill",    tint: purpleChip, size: nodeSize)
            }
        }
        .frame(width: 500, height: 175)
        .accessibilityHidden(true)
    }
}

/// **WelcomeView**
///
/// Welcome screen with brand logo, short pitch, feature chips, and a primary
/// CTA that advances to Setup.
/// - SeeAlso: ``SetupView``, ``HomeView``
struct WelcomeView: View {
    /// Callback fired when the user taps **Let’s get started**.
    var onContinue: () -> Void
    /// Vertical stack: logo → pitch → feature chips → CTA → footer.
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)
            PathmateOrthogonalSLogo()
                .frame(width: 500)
                .padding(.bottom, 16)

            VStack(spacing: 8) {
                Text("Welcome to Pathmate")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("Your step-by-step journey for studying in Australia — checklists, tips, and a simple planner in one place.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            HStack(spacing: 10) {
                Label("Checklists", systemImage: "checkmark.circle")
                Label("Planner", systemImage: "calendar")
                Label("Resources", systemImage: "book")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            Spacer()
            // Primary CTA that advances to setup.
            Button(action: onContinue) {
                Text("Let’s get started")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 20)
            // Support copy to set context.
            Text("Made for students heading to Australia.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 20)
        }
        .padding(.top, 20)
    }
}

#Preview { WelcomeView(onContinue: {}) }
