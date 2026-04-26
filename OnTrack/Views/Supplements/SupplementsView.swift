import SwiftUI

struct SupplementsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var viewModel = SupplementViewModel()
    @State private var showAddSupplement = false
    @State private var showCalculator = false
    @State private var showShare = false
    @State private var showImport = false
    @State private var showNotifications = false
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                GeometryReader { geo in
                    Image(themeManager.currentBackgroundImage)
                        .resizable()
                        .scaledToFill()
                        .grayscale(1.0)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .ignoresSafeArea()
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.84),
                            Color.black.opacity(0.67)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    // HEADER
                    HStack {
                        Text("Supps")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Spacer()
                        HStack(spacing: 16) {
                            Button { showNotifications = true } label: {
                                Image(systemName: "bell")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                            }
                            Button { showImport = true } label: {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                            }
                            // Bug 1: Share Stack moved to the Share Stack page itself.
                            // Single-supplement share is now on SupplementDetailView.
                            Button { showCalculator = true } label: {
                                Image(systemName: "eyedropper.halffull")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                            }
                            Button { showAddSupplement = true } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    // KNOWLEDGE LIBRARY BANNER
                    NavigationLink(destination: KnowledgeLibraryView()) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.5, green: 0.3, blue: 0.9).opacity(0.2))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "book.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color(red: 0.5, green: 0.3, blue: 0.9))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Knowledge Library")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                Text("Research-backed protocols & guides")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            Spacer()
                            Text("Browse →")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(themeManager.currentTheme.primary)
                        }
                        .padding(12)
                        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color(red: 0.5, green: 0.3, blue: 0.9).opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                    // TAB PICKER
                    Picker("", selection: $selectedTab) {
                        Text("Protocol").tag(0)
                        Text("My Stack").tag(1)
                        Text("Stock").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                    // CONTENT
                    TabView(selection: $selectedTab) {
                        ProtocolView(viewModel: viewModel)
                            .tag(0)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        MyStackView(viewModel: viewModel, showAddSupplement: $showAddSupplement)
                            .tag(1)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        StockOverviewView(viewModel: viewModel)
                            .tag(2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: selectedTab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.top, 50)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard let userId = appState.currentUser?.id else { return }
            await viewModel.fetchSupplements(userId: userId)
        }
        .sheet(isPresented: $showAddSupplement) {
            AddSupplementView(viewModel: viewModel)
        }
        .sheet(isPresented: $showCalculator) {
            SupplementDoseCalculatorView(resultDose: .constant(""))
        }
        .sheet(isPresented: $showShare) {
            ShareStackView(viewModel: viewModel)
                .environmentObject(appState)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showImport) {
            ImportStackView(viewModel: viewModel)
                .environmentObject(appState)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
    }
}

// MARK: - Protocol View

struct StackAnalysisResult {
    let conflicts: [String]
    let synergies: [String]
    let suggestions: [String]
}

struct ProtocolView: View {
    @ObservedObject var viewModel: SupplementViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showManageProtocol = false
    @State private var stackAnalysis: StackAnalysisResult? = nil
    @State private var isLoadingAnalysis = false
    @State private var analysisError: String? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.protocolSupplements.isEmpty {
                    emptyState
                } else {
                    groupedList
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 80)
        }
        .background(Color.clear)
        .sheet(isPresented: $showManageProtocol) {
            ManageProtocolSheet(viewModel: viewModel)
                .environmentObject(appState)
                .environmentObject(themeManager)
        }
        .onAppear {
            AnalyticsManager.shared.screen("Supplements")
            if stackAnalysis == nil {
                stackAnalysis = loadAnalysisFromCache()
            }
        }
    }

    private func runStackAnalysis() async {
        guard !viewModel.protocolSupplements.isEmpty else { return }
        isLoadingAnalysis = true
        analysisError = nil
        stackAnalysis = nil

        let supplementList = viewModel.protocolSupplements.map { supp -> String in
            var parts = [supp.name]
            if let dose = supp.dose, !dose.isEmpty { parts.append(dose) }
            parts.append(supp.timing)
            return parts.joined(separator: " — ")
        }.joined(separator: "\n")

        let prompt = """
        You are a supplement and nutrition expert. Analyse this user's current supplement protocol and provide concise, practical insights.

        Current protocol:
        \(supplementList)

        Respond ONLY as a JSON object with this exact structure, no other text:
        {
          "conflicts": ["string", "string"],
          "synergies": ["string", "string"],
          "suggestions": ["string", "string"]
        }

        Rules:
        - conflicts: overlapping ingredients, timing clashes, or combinations to watch out for (max 3 items, empty array if none)
        - synergies: combinations that work well together and why (max 3 items, empty array if none)
        - suggestions: 1-2 practical improvements to consider (max 2 items)
        - Each string should be 1 sentence max, plain language, no markdown
        - If fewer than 2 supplements, return all empty arrays
        """

        do {
            let response = try await AIInsightService.shared.generateInsight(prompt: prompt)
            let cleaned = response
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let data = cleaned.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let conflicts = json["conflicts"] as? [String] ?? []
                let synergies = json["synergies"] as? [String] ?? []
                let suggestions = json["suggestions"] as? [String] ?? []
                let result = StackAnalysisResult(
                    conflicts: conflicts,
                    synergies: synergies,
                    suggestions: suggestions
                )
                await MainActor.run {
                    stackAnalysis = result
                    saveAnalysisToCache(result)
                }
            } else {
                await MainActor.run { analysisError = "Couldn't parse response. Try again." }
            }
        } catch {
            await MainActor.run { analysisError = error.localizedDescription }
        }
        await MainActor.run { isLoadingAnalysis = false }
    }

    private func saveAnalysisToCache(_ result: StackAnalysisResult) {
        let dict: [String: Any] = [
            "conflicts": result.conflicts,
            "synergies": result.synergies,
            "suggestions": result.suggestions,
            "timestamp": Date().timeIntervalSince1970
        ]
        UserDefaults.standard.set(dict, forKey: "stack_analysis_cache")
    }

    private func loadAnalysisFromCache() -> StackAnalysisResult? {
        guard let dict = UserDefaults.standard.dictionary(forKey: "stack_analysis_cache"),
              let timestamp = dict["timestamp"] as? Double,
              Date().timeIntervalSince1970 - timestamp < 86400,
              let conflicts = dict["conflicts"] as? [String],
              let synergies = dict["synergies"] as? [String],
              let suggestions = dict["suggestions"] as? [String] else { return nil }
        return StackAnalysisResult(conflicts: conflicts, synergies: synergies, suggestions: suggestions)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "pills.fill")
                .font(.system(size: 50))
                .foregroundStyle(.white.opacity(0.6))
            Text("No supplements in protocol")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Add supplements from My Stack to build your active routine")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                showManageProtocol = true
            } label: {
                Label("Manage Protocol", systemImage: "list.bullet")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(themeManager.currentTheme.gradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
        }
        .padding(.top, 60)
    }

    private var groupedList: some View {
        let grouped = Dictionary(grouping: viewModel.protocolSupplements) { $0.timing }
        let timingOrder = SupplementTiming.allCases.map { $0.rawValue }
        let sortedKeys = grouped.keys.sorted { a, b in
            (timingOrder.firstIndex(of: a) ?? 99) < (timingOrder.firstIndex(of: b) ?? 99)
        }
        return VStack(spacing: 16) {
            // Stack Analysis card
            StackAnalysisCard(
                supplements: viewModel.protocolSupplements,
                analysis: stackAnalysis,
                isLoading: isLoadingAnalysis,
                error: analysisError,
                onAnalyse: {
                    Task { await runStackAnalysis() }
                }
            )
            .padding(.horizontal)

            // Manage Protocol button
            HStack {
                Spacer()
                Button {
                    showManageProtocol = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet")
                            .font(.caption)
                            .fontWeight(.bold)
                        Text("Manage Protocol")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(themeManager.currentTheme.primary.opacity(0.2))
                    .foregroundStyle(themeManager.currentTheme.primary)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(themeManager.currentTheme.primary.opacity(0.5), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }

            ForEach(sortedKeys, id: \.self) { timing in
                if let supplements = grouped[timing] {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: SupplementTiming(rawValue: timing)?.icon ?? "clock")
                                .font(.caption)
                                .foregroundStyle(themeManager.currentTheme.primary)
                            Text(timing.capitalized)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(themeManager.currentTheme.primary)
                        }
                        .padding(.horizontal)
                        ForEach(supplements) { supplement in
                            ProtocolRowView(supplement: supplement)
                                .padding(.horizontal)
                        }
                    }
                }
            }
        }
    }
}

struct ProtocolRowView: View {
    let supplement: Supplement
    @EnvironmentObject private var themeManager: ThemeManager

    var daysLabel: String {
        let days = supplement.daysOfWeek
        if days == "everyday" || days.isEmpty { return "Every day" }
        if days.hasPrefix("weekly") { return "Weekly" }
        if days.hasPrefix("fortnightly") { return "Fortnightly" }
        if days.hasPrefix("monthly") { return "Monthly" }
        if days == "once" { return "Once" }
        let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let parts = days.components(separatedBy: ",").compactMap { Int($0) }.filter { $0 >= 1 && $0 <= 7 }
        if parts.isEmpty { return days }
        return parts.map { dayNames[$0] }.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(themeManager.currentTheme.primary.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: SupplementTiming(rawValue: supplement.timing)?.icon ?? "pills.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(themeManager.currentTheme.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(supplement.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    if let dose = supplement.dose, !dose.isEmpty {
                        Text(dose)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    Text(daysLabel)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(themeManager.currentTheme.primary.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Manage Protocol Sheet

struct ManageProtocolSheet: View {
    @ObservedObject var viewModel: SupplementViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var stackOnly: [Supplement] {
        viewModel.supplements.filter { !$0.inProtocol }
    }

    var body: some View {
        NavigationStack {
            List {
                // Active Protocol section
                Section {
                    if viewModel.protocolSupplements.isEmpty {
                        Text("No supplements in protocol yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(viewModel.protocolSupplements) { supplement in
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(themeManager.cardColour())
                                        .frame(width: 40, height: 40)
                                    Image(systemName: SupplementTiming(rawValue: supplement.timing)?.icon ?? "pills.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(themeManager.currentTheme.primary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(supplement.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(supplement.timing)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    Task {
                                        guard let userId = appState.currentUser?.id else { return }
                                        await viewModel.updateProtocol(
                                            supplement: supplement,
                                            inProtocol: false,
                                            timing: SupplementTiming(rawValue: supplement.timing) ?? .morning,
                                            daysOfWeek: supplement.daysOfWeek,
                                            reminderEnabled: supplement.reminderEnabled,
                                            userId: userId
                                        )
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } header: {
                    Text("Active Protocol")
                }

                // Add from Stack section
                Section {
                    if stackOnly.isEmpty {
                        Text("All supplements are in protocol.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(stackOnly) { supplement in
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(themeManager.cardColour())
                                        .frame(width: 40, height: 40)
                                    Image(systemName: SupplementTiming(rawValue: supplement.timing)?.icon ?? "pills.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(themeManager.currentTheme.primary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(supplement.name)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(supplement.timing)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    Task {
                                        guard let userId = appState.currentUser?.id else { return }
                                        await viewModel.updateProtocol(
                                            supplement: supplement,
                                            inProtocol: true,
                                            timing: SupplementTiming(rawValue: supplement.timing) ?? .morning,
                                            daysOfWeek: supplement.daysOfWeek,
                                            reminderEnabled: supplement.reminderEnabled,
                                            userId: userId
                                        )
                                    }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(.green)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } header: {
                    Text("Add from Stack")
                }
            }
            .navigationTitle("Protocol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - My Stack View

struct MyStackView: View {
    @ObservedObject var viewModel: SupplementViewModel
    @Binding var showAddSupplement: Bool
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        List {
            if viewModel.supplements.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "pills.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("No supplements added yet")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Tap + to add your first supplement")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    Button {
                        showAddSupplement = true
                    } label: {
                        Label("Add Supplement", systemImage: "plus.circle.fill")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(themeManager.currentTheme.gradient)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.supplements) { supplement in
                    NavigationLink(destination: SupplementDetailView(supplement: supplement, viewModel: viewModel)) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(themeManager.currentTheme.gradient)
                                    .frame(width: 44, height: 44)
                                Image(systemName: SupplementTiming(rawValue: supplement.timing)?.icon ?? "pills.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(supplement.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                HStack(spacing: 4) {
                                    if let dose = supplement.dose, !dose.isEmpty {
                                        Text(dose)
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.6))
                                        Text("·")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                    Text(supplement.timing)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.6))
                                    if let qty = supplement.stockQuantity {
                                        Text("·")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.4))
                                        let qtyStr = qty == qty.rounded() ? String(Int(qty)) : String(format: "%.1f", qty)
                                        let label = supplement.stockUnits.map { "\(qtyStr) \($0)" } ?? qtyStr
                                        HStack(spacing: 2) {
                                            if qty < 10 {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .font(.caption2)
                                                    .foregroundStyle(.orange)
                                            }
                                            Text(label)
                                                .font(.caption)
                                                .foregroundStyle(qty < 10 ? .orange : .white.opacity(0.6))
                                        }
                                    }
                                }
                                if supplement.inProtocol {
                                    Text("In Protocol ✓")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                    .listRowBackground(themeManager.cardColour())
                    .listRowSeparatorTint(Color.white.opacity(0.1))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            Task {
                                guard let userId = appState.currentUser?.id else { return }
                                await viewModel.deleteSupplement(id: supplement.id, userId: userId)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .padding(.bottom, 80)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}

// MARK: - Stack Analysis Card

struct StackAnalysisCard: View {
    let supplements: [Supplement]
    let analysis: StackAnalysisResult?
    let isLoading: Bool
    let error: String?
    let onAnalyse: () -> Void

    private let cardBg = Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92)
    private let purple = Color(red: 0.5, green: 0.3, blue: 0.9)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(purple.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 15))
                        .foregroundStyle(purple)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stack Analysis")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text("AI-powered insights on your protocol")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                if supplements.count < 2 {
                    // Not enough supplements to analyse
                } else if analysis == nil && !isLoading {
                    Button(action: onAnalyse) {
                        Text("Analyse")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(purple.opacity(0.2))
                            .foregroundStyle(purple)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(purple.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                } else if analysis != nil {
                    Button(action: onAnalyse) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(purple)
                        .scaleEffect(0.8)
                    Text("Analysing your stack...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            } else if let error = error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.8))
            } else if let analysis = analysis {
                VStack(spacing: 10) {
                    if !analysis.conflicts.isEmpty {
                        analysisSection(
                            icon: "exclamationmark.triangle.fill",
                            color: .orange,
                            title: "Watch Out For",
                            items: analysis.conflicts
                        )
                    }
                    if !analysis.synergies.isEmpty {
                        analysisSection(
                            icon: "bolt.heart.fill",
                            color: .green,
                            title: "Working Well Together",
                            items: analysis.synergies
                        )
                    }
                    if !analysis.suggestions.isEmpty {
                        analysisSection(
                            icon: "lightbulb.fill",
                            color: purple,
                            title: "Consider Adding",
                            items: analysis.suggestions
                        )
                    }
                }
            } else if supplements.count < 2 {
                Text("Add 2+ supplements to your protocol to analyse your stack.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Tap Analyse to get AI insights on conflicts, synergies, and improvements in your current stack.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(purple.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func analysisSection(icon: String, color: Color, title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(color.opacity(0.7))
                    Text(item)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
