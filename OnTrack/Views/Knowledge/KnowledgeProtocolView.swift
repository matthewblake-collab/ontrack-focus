import SwiftUI

struct KnowledgeProtocolCardView: View {
    let proto: KnowledgeProtocol
    private static let cardBg = Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92)

    private var categoryColor: Color {
        switch proto.category {
        case "Growth Hormone": return .blue
        case "Healing & Recovery": return .green
        case "Weight Loss": return .orange
        case "Cognitive": return .purple
        case "Longevity": return .cyan
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(proto.category)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(categoryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(categoryColor.opacity(0.15))
                        .clipShape(Capsule())
                    Text(proto.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text(proto.compound)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.3))
            }
            if let goal = proto.goal {
                Text(goal)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
            }
            if let phases = proto.phases, !phases.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "list.number")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                    Text("\(phases.count) phase\(phases.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .padding(14)
        .background(Self.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct KnowledgeProtocolDetailView: View {
    let proto: KnowledgeProtocol
    @EnvironmentObject private var themeManager: ThemeManager

    private var categoryColor: Color {
        switch proto.category {
        case "Growth Hormone": return .blue
        case "Healing & Recovery": return .green
        case "Weight Loss": return .orange
        case "Cognitive": return .purple
        case "Longevity": return .cyan
        default: return .gray
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(proto.category)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(categoryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(categoryColor.opacity(0.15))
                        .clipShape(Capsule())
                    Text(proto.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    Text(proto.compound)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                    if let goal = proto.goal {
                        Text(goal)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }

                // Overview
                if let overview = proto.overview {
                    sectionCard(title: "Overview") {
                        Text(overview)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }

                // Phases
                if let phases = proto.phases, !phases.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Protocol Phases")
                            .font(.headline)
                            .foregroundStyle(.white)
                        ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    ZStack {
                                        Circle()
                                            .fill(categoryColor.opacity(0.2))
                                            .frame(width: 28, height: 28)
                                        Text("\(index + 1)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundStyle(categoryColor)
                                    }
                                    Text(phase.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                }
                                VStack(spacing: 6) {
                                    infoRow(icon: "pills.fill", label: "Dose", value: phase.dose)
                                    infoRow(icon: "clock.fill", label: "Frequency", value: phase.frequency)
                                    infoRow(icon: "calendar", label: "Duration", value: phase.duration)
                                    if let notes = phase.notes, !notes.isEmpty {
                                        infoRow(icon: "note.text", label: "Notes", value: notes)
                                    }
                                }
                                .padding(12)
                                .background(Color(red: 0.06, green: 0.09, blue: 0.12).opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .padding(12)
                            .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(categoryColor.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                }

                // Quick Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Info")
                        .font(.headline)
                        .foregroundStyle(.white)
                    VStack(spacing: 0) {
                        if let ratio = proto.bacWaterRatio {
                            infoRow(icon: "drop.fill", label: "Reconstitution", value: ratio)
                            Divider().background(Color.white.opacity(0.08)).padding(.vertical, 4)
                        }
                        if let storage = proto.storage {
                            infoRow(icon: "snowflake", label: "Storage", value: storage)
                            Divider().background(Color.white.opacity(0.08)).padding(.vertical, 4)
                        }
                        if let halfLife = proto.halfLife {
                            infoRow(icon: "timer", label: "Half-Life", value: halfLife)
                        }
                    }
                    .padding(14)
                    .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Stack With
                if let stackWith = proto.stackWith, !stackWith.isEmpty {
                    sectionCard(title: "Stack With") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(stackWith, id: \.self) { item in
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(categoryColor.opacity(0.8))
                                        .font(.caption)
                                    Text(item)
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                            }
                        }
                    }
                }

                // Warnings
                if let warnings = proto.warnings, !warnings.isEmpty {
                    sectionCard(title: "Important Notes") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(warnings, id: \.self) { warning in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.yellow.opacity(0.8))
                                        .font(.caption)
                                        .padding(.top, 2)
                                    Text(warning)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.7))
                                }
                            }
                        }
                    }
                }

                Text("For educational purposes only. Not medical advice. Consult a healthcare professional before making any changes.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .background(themeManager.backgroundColour())
        .navigationTitle(proto.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            VStack(alignment: .leading) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
