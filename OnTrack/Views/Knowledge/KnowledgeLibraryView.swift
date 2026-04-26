import SwiftUI

struct KnowledgeLibraryView: View {
    @State private var viewModel = KnowledgeViewModel()
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selectedCategory = "All"
    @State private var searchText = ""
    @State private var showDisclaimer = false
    @State private var showFavouritesOnly = false
    @State private var showProtocols = false

    private let categories = ["All", "Supplements", "Breathwork", "Recovery", "Workouts", "Nutrition"]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Background
                GeometryReader { geo in
                    ZStack {
                        Image(themeManager.currentBackgroundImage)
                            .resizable()
                            .scaledToFill()
                            .grayscale(1.0)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.67),
                                Color.black.opacity(0.47),
                                Color.black.opacity(0.72)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Library")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Text("Research-backed protocols & guides")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    // Search bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.white.opacity(0.4))
                        TextField("Search library...", text: $searchText)
                            .foregroundStyle(.white)
                            .autocorrectionDisabled()
                    }
                    .padding(10)
                    .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .onChange(of: searchText) { _, newValue in
                        Task {
                            if newValue.isEmpty {
                                await viewModel.fetchAll(category: selectedCategory == "All" ? nil : selectedCategory)
                            } else {
                                await viewModel.searchItems(query: newValue)
                            }
                        }
                    }

                    // Category + Favourites tabs
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // Protocols tab
                            Button {
                                showProtocols = true
                                showFavouritesOnly = false
                                selectedCategory = "All"
                                searchText = ""
                                Task { await viewModel.fetchProtocols() }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: showProtocols ? "list.clipboard.fill" : "list.clipboard")
                                        .font(.caption)
                                    Text("Protocols")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(showProtocols ? .white : .white.opacity(0.6))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(showProtocols ? Color.blue.opacity(0.6) : Color.white.opacity(0.08))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            // Favourites tab
                            Button {
                                showFavouritesOnly = true
                                showProtocols = false
                                selectedCategory = "All"
                                searchText = ""
                                Task { await viewModel.fetchAll() }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: showFavouritesOnly ? "heart.fill" : "heart")
                                        .font(.caption)
                                    Text("Favourites")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(showFavouritesOnly ? .white : .white.opacity(0.6))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(showFavouritesOnly ? Color.pink.opacity(0.7) : Color.white.opacity(0.08))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            // Category tabs
                            ForEach(categories, id: \.self) { category in
                                Button {
                                    showFavouritesOnly = false
                                    showProtocols = false
                                    selectedCategory = category
                                    searchText = ""
                                    Task {
                                        await viewModel.fetchAll(category: category == "All" ? nil : category)
                                    }
                                } label: {
                                    Text(category)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundStyle(selectedCategory == category && !showFavouritesOnly && !showProtocols ? .white : .white.opacity(0.6))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(selectedCategory == category && !showFavouritesOnly && !showProtocols ? themeManager.currentTheme.primary : Color.white.opacity(0.08))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 12)

                    // Content
                    if showProtocols {
                        // Protocols view
                        if viewModel.isLoading {
                            Spacer()
                            ProgressView().tint(.white)
                            Spacer()
                        } else if viewModel.protocols.isEmpty {
                            Spacer()
                            VStack(spacing: 12) {
                                Image(systemName: "list.clipboard")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.white.opacity(0.4))
                                Text("No protocols found")
                                    .font(.headline)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            Spacer()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(viewModel.protocols) { proto in
                                        NavigationLink(destination: KnowledgeProtocolDetailView(proto: proto)) {
                                            KnowledgeProtocolCardView(proto: proto)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 20)
                            }
                        }
                    } else if viewModel.isLoading {
                        Spacer()
                        ProgressView().tint(.white)
                        Spacer()
                    } else if viewModel.items.isEmpty || (showFavouritesOnly && viewModel.savedItemIds.isEmpty) {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: showFavouritesOnly ? "heart.slash" : "book.closed")
                                .font(.system(size: 48))
                                .foregroundStyle(.white.opacity(0.4))
                            Text(showFavouritesOnly ? "No favourites yet" : "No items found")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.6))
                            if showFavouritesOnly {
                                Text("Tap the heart on any item to save it here")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.4))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                let displayItems = showFavouritesOnly
                                    ? viewModel.items.filter { viewModel.savedItemIds.contains($0.id) }
                                    : viewModel.items
                                ForEach(displayItems) { item in
                                    NavigationLink(destination: KnowledgeDetailView(item: item, viewModel: viewModel, userId: appState.currentUser?.id)) {
                                        KnowledgeCardView(
                                            item: item,
                                            isSaved: viewModel.savedItemIds.contains(item.id),
                                            onToggleSave: {
                                                Task {
                                                    guard let uid = appState.currentUser?.id else { return }
                                                    await viewModel.toggleSave(itemId: item.id, userId: uid)
                                                }
                                            }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.fetchAll()
                if let userId = appState.currentUser?.id {
                    await viewModel.fetchSaves(userId: userId)
                }
                if !UserDefaults.standard.bool(forKey: "knowledge_disclaimer_accepted") {
                    showDisclaimer = true
                }
            }
            .sheet(isPresented: $showDisclaimer) {
                KnowledgeDisclaimerView {
                    UserDefaults.standard.set(true, forKey: "knowledge_disclaimer_accepted")
                    showDisclaimer = false
                }
                .interactiveDismissDisabled()
            }
        }
    }
}

// MARK: - Disclaimer Modal

struct KnowledgeDisclaimerView: View {
    let onAccept: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.09, blue: 0.12)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.yellow)

                Text("Important Disclaimer")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                Text("The information in this library is for educational and research purposes only. It does not constitute medical advice. Always consult a qualified healthcare professional before starting any supplement, protocol, or exercise program.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer()

                Button {
                    onAccept()
                } label: {
                    Text("I Understand")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.3, green: 0.6, blue: 1.0), Color(red: 0.5, green: 0.3, blue: 0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(24)
    }
}
