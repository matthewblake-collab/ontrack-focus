import SwiftUI
import Supabase

struct CreateSessionView: View {
    @Bindable var viewModel: SessionViewModel
    let group: AppGroup
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var titleSuggestions: [String] = []
    @State private var showTitleSuggestions = false
    @State private var selectedTitleSuggestion: String?
    @State private var locationSuggestions: [String] = []
    @State private var showLocationSuggestions = false
    @State private var selectedLocationSuggestion: String?
    @State private var enableReminder = true
    @State private var reminderMinutes = 30

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // SESSION DETAILS
                    SectionCard(title: "Session Details") {
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 0) {
                                OnTrackTextField(placeholder: "Title", text: $viewModel.newTitle)
                                    .onChange(of: viewModel.newTitle) { _, newValue in
                                        if newValue == selectedTitleSuggestion {
                                            selectedTitleSuggestion = nil
                                            return
                                        }
                                        selectedTitleSuggestion = nil
                                        Task { await fetchTitleSuggestions(query: newValue) }
                                    }
                                if showTitleSuggestions {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(titleSuggestions, id: \.self) { suggestion in
                                            Button {
                                                selectedTitleSuggestion = suggestion
                                                viewModel.newTitle = suggestion
                                                showTitleSuggestions = false
                                                titleSuggestions = []
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
                                            if suggestion != titleSuggestions.last {
                                                Divider().padding(.leading, 12)
                                            }
                                        }
                                    }
                                    .background(Color(.systemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                                }
                            }
                            OnTrackTextField(placeholder: "Description (optional)", text: $viewModel.newDescription)
                            VStack(alignment: .leading, spacing: 0) {
                                OnTrackTextField(placeholder: "Location (optional)", text: $viewModel.newLocation)
                                    .onChange(of: viewModel.newLocation) { _, newValue in
                                        if newValue == selectedLocationSuggestion {
                                            selectedLocationSuggestion = nil
                                            return
                                        }
                                        selectedLocationSuggestion = nil
                                        Task { await fetchLocationSuggestions(query: newValue) }
                                    }
                                if showLocationSuggestions {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(locationSuggestions, id: \.self) { suggestion in
                                            Button {
                                                selectedLocationSuggestion = suggestion
                                                viewModel.newLocation = suggestion
                                                showLocationSuggestions = false
                                                locationSuggestions = []
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
                                            if suggestion != locationSuggestions.last {
                                                Divider().padding(.leading, 12)
                                            }
                                        }
                                    }
                                    .background(Color(.systemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                                }
                            }
                            Picker("Session Type", selection: $viewModel.newSessionType) {
                                Text("No type").tag("")
                                ForEach(SessionViewModel.sessionTypes, id: \.self) { type in
                                    Text(type).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(themeManager.currentTheme.primary)
                        }
                    }

                    // DATE & TIME
                    SectionCard(title: "Date & Time") {
                        DatePicker("Start Date",
                                   selection: $viewModel.newProposedAt,
                                   displayedComponents: [.date, .hourAndMinute])
                    }

                    // REPEAT
                    SectionCard(title: "Repeat") {
                        VStack(alignment: .leading, spacing: 16) {
                            Picker("Repeat", selection: $viewModel.recurrenceRule) {
                                ForEach(RecurrenceRule.allCases) { rule in
                                    Text(rule.label).tag(rule)
                                }
                            }
                            .pickerStyle(.menu)

                            if viewModel.recurrenceRule == .custom {
                                CustomDatePickerView(
                                    selectedDates: $viewModel.customDates,
                                    baseTime: viewModel.newProposedAt
                                )
                                if !viewModel.customDates.isEmpty {
                                    Text("\(viewModel.customDates.count) day\(viewModel.customDates.count == 1 ? "" : "s") selected")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else if viewModel.recurrenceRule != .none {
                                DatePicker("Repeat Until",
                                           selection: $viewModel.recurrenceEndDate,
                                           displayedComponents: [.date])
                                let count = previewCount()
                                Text("This will create \(count) session\(count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // VISIBILITY
                    SectionCard(title: "Visibility") {
                        Toggle(isOn: Binding(
                            get: { viewModel.newVisibility == "friends" },
                            set: { viewModel.newVisibility = $0 ? "friends" : "group" }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Visible to friends")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                Text("Friends can see and join this session")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .tint(Color(red: 0.15, green: 0.55, blue: 0.38))
                    }

                    // REMINDER
                    SectionCard(title: "Reminder") {
                        VStack(spacing: 12) {
                            Toggle(isOn: $enableReminder) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Set reminder")
                                        .font(.subheadline)
                                    Text("Get notified before the session starts")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tint(Color(red: 0.15, green: 0.55, blue: 0.38))

                            if enableReminder {
                                Picker("Remind me", selection: $reminderMinutes) {
                                    Text("15 min before").tag(15)
                                    Text("30 min before").tag(30)
                                    Text("1 hour before").tag(60)
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }

                    // CREATE BUTTON
                    Button {
                        Task {
                            guard let userId = appState.currentUser?.id else { return }
                            let createdSession = await viewModel.createSession(groupId: group.id, userId: userId)
                            if viewModel.errorMessage == nil {
                                if enableReminder, let session = createdSession {
                                    NotificationManager.shared.scheduleSessionReminder(session: session, minutesBefore: reminderMinutes)
                                }
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Create Session")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundStyle(.white)
                        }
                    }
                    .background(themeManager.currentTheme.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(viewModel.newTitle.isEmpty || viewModel.isLoading || (viewModel.recurrenceRule == .custom && viewModel.customDates.isEmpty))
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(themeManager.backgroundColour())
            .onAppear { viewModel.newVisibility = "friends" }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    func fetchTitleSuggestions(query: String) async {
        guard query.count >= 1,
              let userId = appState.currentUser?.id else {
            titleSuggestions = []
            showTitleSuggestions = false
            return
        }
        struct TitleRow: Decodable { let title: String }
        let results: [TitleRow] = (try? await supabase
            .from("sessions")
            .select("title")
            .eq("created_by", value: userId)
            .ilike("title", pattern: "\(query)%")
            .order("title", ascending: true)
            .limit(6)
            .execute()
            .value) ?? []
        let unique = Array(Set(results.map { $0.title })).sorted()
        titleSuggestions = unique
        showTitleSuggestions = !unique.isEmpty
    }

    func fetchLocationSuggestions(query: String) async {
        guard query.count >= 1,
              let userId = appState.currentUser?.id else {
            locationSuggestions = []
            showLocationSuggestions = false
            return
        }
        struct LocationRow: Decodable { let location: String? }
        let results: [LocationRow] = (try? await supabase
            .from("sessions")
            .select("location")
            .eq("created_by", value: userId)
            .ilike("location", pattern: "\(query)%")
            .order("location", ascending: true)
            .limit(6)
            .execute()
            .value) ?? []
        let unique = Array(Set(results.compactMap { $0.location })).sorted()
        locationSuggestions = unique
        showLocationSuggestions = !unique.isEmpty
    }

    func previewCount() -> Int {
        var count = 0
        var current = viewModel.newProposedAt
        let calendar = Calendar.current
        guard let component = viewModel.recurrenceRule.calendarComponent else { return 1 }
        while current <= viewModel.recurrenceEndDate {
            count += 1
            current = calendar.date(byAdding: component, value: viewModel.recurrenceRule.interval, to: current) ?? current
        }
        return count
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 0) {
                content
                    .padding()
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
}

struct OnTrackTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .padding(10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct CustomDatePickerView: View {
    @Binding var selectedDates: [Date]
    let baseTime: Date
    @State private var displayedMonth: Date = Date()
    @EnvironmentObject private var themeManager: ThemeManager

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let dayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

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
        let timeComponents = calendar.dateComponents([.hour, .minute], from: baseTime)
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = timeComponents.hour
        dateComponents.minute = timeComponents.minute
        guard let fullDate = calendar.date(from: dateComponents) else { return }

        if let index = selectedDates.firstIndex(where: { calendar.isDate($0, inSameDayAs: date) }) {
            selectedDates.remove(at: index)
        } else {
            selectedDates.append(fullDate)
            selectedDates.sort()
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.primary)
                }

                Spacer()

                Text(monthTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.primary)
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(dayLabels, id: \.self) { label in
                    Text(label)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
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
                                .overlay(
                                    Circle()
                                        .stroke(selected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
                                )
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
