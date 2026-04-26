import SwiftUI
import Supabase

struct AddSupplementView: View {
    @ObservedObject var viewModel: SupplementViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var recurrenceRule: SupplementRecurrence = .daily
    @State private var recurrenceEndDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var customDates: [Date] = []
    @State private var showDoseCalculator = false
    @State private var supplementSuggestions: [String] = []
    @State private var showSuggestions: Bool = false
    @State private var addToProtocol: Bool = false
    @State private var selectedSuggestion: String?
    @State private var matchedKnowledgeItem: KnowledgeItem?
    @State private var showKnowledgeDetail = false
    @State private var knowledgeVM = KnowledgeViewModel()

    private let unitOptions = ["g", "mg", "ml", "mcg", "IU", "capsules", "tablets", "drops", "tsp", "tbsp"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    detailsSection
                    protocolToggleSection
                    if addToProtocol {
                        timingSection
                        scheduleSection
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }

                    saveButton
                }
                .padding(.vertical)
            }
            .background(themeManager.backgroundColour())
            .navigationTitle("Add Supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showDoseCalculator) {
                SupplementDoseCalculatorView(resultDose: $viewModel.newDoseAmount)
            }
            .sheet(isPresented: $showKnowledgeDetail) {
                if let item = matchedKnowledgeItem {
                    NavigationStack {
                        KnowledgeDetailView(item: item, viewModel: knowledgeVM, userId: appState.currentUser?.id)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Done") { showKnowledgeDetail = false }
                                }
                            }
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var detailsSection: some View {
        formCard(title: "Supplement Details") {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    OnTrackTextField(placeholder: "Name (e.g. Creatine)", text: $viewModel.newName)
                        .onChange(of: viewModel.newName) { _, newValue in
                            if newValue == selectedSuggestion {
                                selectedSuggestion = nil
                                Task { await lookupKnowledgeItem(name: newValue) }
                                return
                            }
                            selectedSuggestion = nil
                            Task {
                                await fetchSuggestions(query: newValue)
                                await lookupKnowledgeItem(name: newValue)
                            }
                        }
                    if showSuggestions {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(supplementSuggestions, id: \.self) { suggestion in
                                Button {
                                    selectedSuggestion = suggestion
                                    viewModel.newName = suggestion
                                    showSuggestions = false
                                    supplementSuggestions = []
                                } label: {
                                    HStack {
                                        Text(suggestion)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "arrow.up.left")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                if suggestion != supplementSuggestions.last {
                                    Divider().padding(.leading, 12)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                    }
                }

                if let item = matchedKnowledgeItem {
                    Button {
                        showKnowledgeDetail = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "book.fill")
                                .font(.caption2)
                            Text("Learn more about \(item.title)")
                                .font(.caption)
                                .fontWeight(.medium)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                        }
                        .foregroundStyle(themeManager.currentTheme.primary)
                    }
                    .buttonStyle(.plain)
                }

                Button { showDoseCalculator = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "eyedropper.halffull")
                            .font(.subheadline)
                        Text("Calculate dose")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                HStack(spacing: 12) {
                    TextField("Amount (e.g. 5)", text: $viewModel.newDoseAmount)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                    Picker("Unit", selection: $viewModel.newDoseUnits) {
                        ForEach(unitOptions, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(themeManager.currentTheme.primary)
                }

                OnTrackTextField(placeholder: "Notes (optional)", text: $viewModel.newNotes)

                Divider()

                HStack(spacing: 12) {
                    OnTrackTextField(placeholder: "Stock qty (optional)", text: $viewModel.newStockQuantity)
                        .keyboardType(.decimalPad)
                    Picker("Unit", selection: $viewModel.newStockUnits) {
                        ForEach(unitOptions, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(themeManager.currentTheme.primary)
                }

                Divider()

                Toggle("Start Date", isOn: $viewModel.newStartDateEnabled)
                if viewModel.newStartDateEnabled {
                    DatePicker("", selection: $viewModel.newStartDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(themeManager.currentTheme.primary)
                }
            }
        }
    }

    private var timingSection: some View {
        formCard(title: "When to Take") {
            VStack(spacing: 12) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    ForEach(SupplementTiming.allCases) { timing in
                        Button {
                            viewModel.newTiming = timing
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: timing.icon)
                                    .font(.system(size: 20))
                                Text(timing.rawValue)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(viewModel.newTiming == timing ? themeManager.currentTheme.primary : Color(.systemGray6))
                            .foregroundStyle(viewModel.newTiming == timing ? .white : .secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if viewModel.newTiming == .custom {
                    DatePicker("Custom Time", selection: $viewModel.newCustomTime, displayedComponents: .hourAndMinute)
                }
            }
        }
    }

    private var scheduleSection: some View {
        formCard(title: "Schedule") {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Repeat", selection: $recurrenceRule) {
                    ForEach(SupplementRecurrence.allCases) { rule in
                        Text(rule.label).tag(rule)
                    }
                }
                .pickerStyle(.menu)
                .tint(themeManager.currentTheme.primary)

                if recurrenceRule == .custom {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select dates")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        CustomSupplementDatePicker(
                            selectedDates: $customDates,
                            themeManager: themeManager
                        )
                        if !customDates.isEmpty {
                            Text("\(customDates.count) date\(customDates.count == 1 ? "" : "s") selected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if recurrenceRule != .once {
                    DatePicker("End Date", selection: $recurrenceEndDate, in: Date()..., displayedComponents: .date)
                        .tint(themeManager.currentTheme.primary)

                    let count = previewCount()
                    Text("This will create \(count) dose\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            Task {
                guard let userId = appState.currentUser?.id else { return }
                viewModel.newDaysOfWeek = addToProtocol
                    ? recurrenceRule.storageValue(customDates: customDates, endDate: recurrenceEndDate)
                    : "everyday"
                viewModel.newInProtocol = addToProtocol
                if !viewModel.newName.isEmpty {
                    await saveCustomType(name: viewModel.newName)
                }
                await viewModel.addSupplement(userId: userId)
                if viewModel.errorMessage == nil {
                    dismiss()
                }
            }
        } label: {
            if viewModel.isLoading {
                ProgressView().tint(.white).frame(maxWidth: .infinity).padding()
            } else {
                Text("Add Supplement")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundStyle(.white)
            }
        }
        .background(themeManager.currentTheme.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(viewModel.newName.isEmpty || viewModel.isLoading)
        .padding(.horizontal)
    }

    private var protocolToggleSection: some View {
        formCard(title: "Protocol") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Add to Protocol", isOn: $addToProtocol)
                    .tint(themeManager.currentTheme.primary)
                Text(addToProtocol
                    ? "This supplement will appear in your daily actions."
                    : "Saved to My Stack only. Add to Protocol later from the Supplements tab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func previewCount() -> Int {
        let calendar = Calendar.current
        var count = 0
        var current = Date()
        guard let component = recurrenceRule.calendarComponent,
              let interval = recurrenceRule.interval else { return 1 }
        while current <= recurrenceEndDate {
            count += 1
            current = calendar.date(byAdding: component, value: interval, to: current) ?? recurrenceEndDate
        }
        return max(count, 1)
    }

    private func fetchSuggestions(query: String) async {
        guard query.count >= 1 else {
            supplementSuggestions = []
            showSuggestions = false
            return
        }
        do {
            struct SupplementType: Decodable { let name: String }
            let results: [SupplementType] = try await supabase
                .from("supplement_types")
                .select("name")
                .ilike("name", value: "\(query)%")
                .order("name", ascending: true)
                .limit(6)
                .execute()
                .value
            supplementSuggestions = results.map { $0.name }
            showSuggestions = !supplementSuggestions.isEmpty
        } catch {
            supplementSuggestions = []
            showSuggestions = false
        }
    }

    private func lookupKnowledgeItem(name: String) async {
        guard name.count >= 3 else {
            matchedKnowledgeItem = nil
            return
        }
        do {
            let results: [KnowledgeItem] = try await supabase
                .from("knowledge_items")
                .select()
                .eq("is_published", value: true)
                .eq("category", value: "Supplements")
                .ilike("title", pattern: "%\(name)%")
                .limit(1)
                .execute()
                .value
            matchedKnowledgeItem = results.first
        } catch {
            matchedKnowledgeItem = nil
        }
    }

    private func saveCustomType(name: String) async {
        guard let userId = appState.currentUser?.id else { return }
        try? await supabase
            .from("supplement_types")
            .upsert(["name": name, "is_global": "false", "created_by": userId.uuidString], onConflict: "name")
            .execute()
    }

    @ViewBuilder
    private func formCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            VStack(alignment: .leading, spacing: 0) {
                content()
                    .padding()
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
}

// MARK: - Recurrence enum

enum SupplementRecurrence: String, CaseIterable, Identifiable {
    case once = "once"
    case daily = "daily"
    case weekly = "weekly"
    case fortnightly = "fortnightly"
    case monthly = "monthly"
    case custom = "custom"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .once: return "Just once"
        case .daily: return "Every day"
        case .weekly: return "Weekly"
        case .fortnightly: return "Fortnightly"
        case .monthly: return "Monthly"
        case .custom: return "Custom dates"
        }
    }

    var calendarComponent: Calendar.Component? {
        switch self {
        case .daily: return .day
        case .weekly: return .weekOfYear
        case .fortnightly: return .weekOfYear
        case .monthly: return .month
        default: return nil
        }
    }

    var interval: Int? {
        switch self {
        case .daily: return 1
        case .weekly: return 1
        case .fortnightly: return 2
        case .monthly: return 1
        default: return nil
        }
    }

    func storageValue(customDates: [Date], endDate: Date) -> String {
        switch self {
        case .once: return "once"
        case .daily: return "everyday"
        case .weekly: return "weekly|\(endDate.timeIntervalSince1970)"
        case .fortnightly: return "fortnightly|\(endDate.timeIntervalSince1970)"
        case .monthly: return "monthly|\(endDate.timeIntervalSince1970)"
        case .custom:
            let timestamps = customDates.map { String($0.timeIntervalSince1970) }.joined(separator: ",")
            return "custom|\(timestamps)"
        }
    }
}

// MARK: - Simple date picker for custom supplement dates

struct CustomSupplementDatePicker: View {
    @Binding var selectedDates: [Date]
    let themeManager: ThemeManager

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let dayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    @State private var displayedMonth: Date = Date()

    var daysInMonth: [Date?] {
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: monthStart) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(date)
            }
        }
        return days
    }

    var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    func isSelected(_ date: Date) -> Bool {
        selectedDates.contains { calendar.isDate($0, inSameDayAs: date) }
    }

    func isPast(_ date: Date) -> Bool {
        calendar.startOfDay(for: date) < calendar.startOfDay(for: Date())
    }

    func toggleDate(_ date: Date) {
        if let index = selectedDates.firstIndex(where: { calendar.isDate($0, inSameDayAs: date) }) {
            selectedDates.remove(at: index)
        } else {
            selectedDates.append(date)
            selectedDates.sort()
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.left").foregroundStyle(.primary)
                }
                Spacer()
                Text(monthTitle).font(.subheadline).fontWeight(.semibold)
                Spacer()
                Button {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.right").foregroundStyle(.primary)
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(dayLabels, id: \.self) { label in
                    Text(label).font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)
                }
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        let selected = isSelected(date)
                        let past = isPast(date)
                        Button {
                            if !past { toggleDate(date) }
                        } label: {
                            Text("\(calendar.component(.day, from: date))")
                                .font(.subheadline)
                                .frame(width: 34, height: 34)
                                .background(selected ? themeManager.currentTheme.primary : Color.clear)
                                .foregroundStyle(selected ? .white : past ? .secondary : .primary)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(selected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(past)
                    } else {
                        Color.clear.frame(width: 34, height: 34)
                    }
                }
            }
        }
    }
}
