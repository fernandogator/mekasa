import SwiftUI

/// A–E letter badge for a product's health grade (REQ-021).
struct HealthGradeBadge: View {
    let grade: String?
    var size: CGFloat = 28

    var body: some View {
        Text(grade?.uppercased() ?? "–")
            .font(.system(size: size * 0.5, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(HealthGrade.color(for: grade))
            .clipShape(Circle())
            .accessibilityLabel("Health grade \(HealthGrade.label(for: grade))")
            .accessibilityIdentifier(TestIdentifiers.healthGradeBadge)
    }
}

/// Compact "⚠ Leo" capsule for list rows: this item contains something a member avoids.
struct AffectedMembersChip: View {
    let warnings: [MemberWarning]

    var body: some View {
        if !warnings.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(AffectedMembers.names(warnings))
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(MekasaTheme.accent)
            .clipShape(Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AffectedMembers.summary(warnings))
            .accessibilityIdentifier(TestIdentifiers.affectedMembersChip)
        }
    }
}

/// One-line "Contains MSG · affects Leo" caption under a row title.
struct AffectedMembersCaption: View {
    let warnings: [MemberWarning]

    var body: some View {
        if !warnings.isEmpty {
            Text("\(AffectedMembers.contains(warnings)) · affects \(AffectedMembers.names(warnings))")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(MekasaTheme.accent)
                .lineLimit(2)
                .accessibilityIdentifier(TestIdentifiers.affectedMembersCaption)
        }
    }
}

/// "Leo avoids MSG, Peanuts" banner shown at scan-confirm and on item detail (REQ-021 AC2).
struct MemberWarningBanner: View {
    let warnings: [MemberWarning]

    var body: some View {
        if !warnings.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(warnings.count == 1 ? "Heads up" : "Heads up · \(warnings.count) members")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(0.6)
                }
                .foregroundStyle(MekasaTheme.accent)
                ForEach(warnings) { warning in
                    Text(warning.sentence)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(MekasaTheme.brand)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MekasaTheme.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(MekasaTheme.accent.opacity(0.35), lineWidth: 1)
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(TestIdentifiers.memberWarningBanner)
        }
    }
}

/// Grade, Nutri-Score / NOVA, additives, allergens and traces (REQ-021 AC3).
struct HealthSummaryCard: View {
    let health: ProductHealth
    @State private var showIngredients = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                HealthGradeBadge(grade: health.grade, size: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text(HealthGrade.label(for: health.grade))
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(MekasaTheme.brand)
                    if let score = health.score {
                        Text("\(score)/100 · \(health.summaryLine)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(MekasaTheme.textMuted)
                    } else if !health.summaryLine.isEmpty {
                        Text(health.summaryLine)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(MekasaTheme.textMuted)
                    } else {
                        Text("Open Food Facts has no nutrition data for this product yet.")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(MekasaTheme.textMuted)
                    }
                }
                Spacer(minLength: 0)
            }

            if !health.additives.isEmpty {
                section("Additives") {
                    ForEach(health.additives) { additive in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(HealthGrade.concernColor(additive.concern))
                                .frame(width: 10, height: 10)
                            Text(additive.code)
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(MekasaTheme.brand)
                                .frame(width: 52, alignment: .leading)
                            Text(additive.name)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(MekasaTheme.brand)
                                .lineLimit(2)
                            Spacer(minLength: 0)
                            Text(additive.concern.capitalized)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(HealthGrade.concernColor(additive.concern))
                        }
                    }
                }
            }

            if !health.allergens.isEmpty {
                section("Contains") { chipRow(health.allergens, tint: MekasaTheme.accent) }
            }
            if !health.traces.isEmpty {
                section("May contain") { chipRow(health.traces, tint: MekasaTheme.textMuted) }
            }
            if !health.flags.isEmpty {
                section("Also flagged") { chipRow(health.flags, tint: MekasaTheme.textMuted) }
            }

            if let ingredients = health.ingredientsText, !ingredients.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showIngredients.toggle() }
                } label: {
                    HStack {
                        Text(showIngredients ? "Hide ingredients" : "Show ingredients")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Image(systemName: showIngredients ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(MekasaTheme.textMuted)
                }
                .buttonStyle(.plain)
                if showIngredients {
                    Text(ingredients)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(MekasaTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("Grade from Open Food Facts Nutri-Score, NOVA processing group and additive risk. Informational only — not medical advice.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(MekasaTheme.brandMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(MekasaTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(TestIdentifiers.healthSummaryCard)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(MekasaTheme.textMuted)
            content()
        }
    }

    private func chipRow(_ values: [String], tint: Color) -> some View {
        FlowChips(values: values) { value in
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(tint.opacity(0.1))
                .clipShape(Capsule())
        }
    }
}

/// Simple wrapping chip layout (iOS 16+ `Layout`).
struct FlowChips<Content: View>: View {
    let values: [String]
    let spacing: CGFloat
    let chip: (String) -> Content

    init(values: [String], spacing: CGFloat = 8, @ViewBuilder chip: @escaping (String) -> Content) {
        self.values = values
        self.spacing = spacing
        self.chip = chip
    }

    var body: some View {
        FlowLayout(spacing: spacing) {
            ForEach(values, id: \.self) { value in
                chip(value)
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var width: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: maxWidth == .infinity ? width : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
