import SwiftUI

struct KnowledgeDetailView: View {
    let item: KnowledgeItem
    @State var viewModel: KnowledgeViewModel
    let userId: UUID?
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var relatedItems: [KnowledgeItem] = []
    @State private var showAddToProtocol = false
    @State private var supplementViewModel = SupplementViewModel()

    private var isSaved: Bool {
        guard let userId else { return false }
        _ = userId // suppress unused warning — savedItemIds is keyed by itemId
        return viewModel.savedItemIds.contains(item.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    categoryPill
                    Text(item.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                // Save button
                if userId != nil {
                    Button {
                        Task {
                            guard let uid = userId else { return }
                            await viewModel.toggleSave(itemId: item.id, userId: uid)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isSaved ? "heart.fill" : "heart")
                            Text(isSaved ? "Favourited ♥" : "Add to Favourites")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                        .foregroundStyle(isSaved ? .pink : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(isSaved ? Color.pink.opacity(0.4) : Color.white.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button {
                        supplementViewModel.prefillFromKnowledgeItem(item)
                        showAddToProtocol = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add to Protocol")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.green.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                // Description
                sectionCard(title: "Overview") {
                    Text(item.description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }

                // Benefits
                if let benefits = item.benefits, !benefits.isEmpty {
                    sectionCard(title: "Benefits") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(benefits, id: \.self) { benefit in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                        .padding(.top, 2)
                                    Text(benefit)
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                            }
                        }
                    }
                }

                // Quick info
                if item.dosage != nil || item.duration != nil || item.difficulty != nil {
                    sectionCard(title: "Quick Info") {
                        VStack(alignment: .leading, spacing: 8) {
                            if let dosage = item.dosage {
                                infoRow(icon: "pills.fill", label: "Dosage", value: dosage)
                            }
                            if let duration = item.duration {
                                infoRow(icon: "clock.fill", label: "Duration", value: duration)
                            }
                            if let difficulty = item.difficulty {
                                infoRow(icon: "speedometer", label: "Level", value: difficulty)
                            }
                        }
                    }
                }

                // Sources
                if let sources = item.sources, !sources.isEmpty {
                    sectionCard(title: "Sources") {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(sources, id: \.self) { source in
                                Text("• \(source)")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                    }
                }

                // Related items
                if !relatedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Related")
                            .font(.headline)
                            .foregroundStyle(.white)
                        ForEach(relatedItems) { related in
                            NavigationLink(destination: KnowledgeDetailView(item: related, viewModel: viewModel, userId: userId)) {
                                KnowledgeCardView(
                                    item: related,
                                    isSaved: viewModel.savedItemIds.contains(related.id),
                                    onToggleSave: {
                                        Task {
                                            guard let uid = userId else { return }
                                            await viewModel.toggleSave(itemId: related.id, userId: uid)
                                        }
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Permanent disclaimer footer
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
        .navigationTitle(item.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            relatedItems = await viewModel.fetchRelatedItems(for: item.id)
        }
        .sheet(isPresented: $showAddToProtocol) {
            AddSupplementView(viewModel: supplementViewModel)
                .environmentObject(appState)
                .environmentObject(themeManager)
        }
    }

    private var categoryPill: some View {
        let color: Color = {
            switch item.category {
            case "Supplements": return .green
            case "Breathwork": return .cyan
            case "Recovery": return .blue
            case "Workouts": return .orange
            case "Nutrition": return .yellow
            default: return .gray
            }
        }()
        return Text(item.category)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
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
