import SwiftUI
import Supabase

struct AddHabitView: View {
    @ObservedObject var viewModel: HabitViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var frequency: HabitFrequency = .daily
    @State private var selectedDays: Set<String> = []
    @State private var weeklyTarget = 3
    @State private var monthlyTarget = 10
    @State private var hasTarget = false
    @State private var targetCount = 1
    @State private var isPrivate = false
    @State private var visibleToFriends: Bool = false
    @State private var showVisibilityPrompt = false
    @State private var isOneOff: Bool = false
    @State private var oneOffDate: Date = Date()
    @State private var selectedGroupId: UUID? = nil
    @State private var userGroups: [AppGroup] = []
    @State private var selectedHabitType: String = ""

    let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    @ViewBuilder
    private func formCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).padding(.horizontal)
            VStack(alignment: .leading, spacing: 0) {
                content().padding()
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                themeManager.backgroundColour().ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        formCard(title: "Habit Name") {
                            TextField("e.g. Morning run", text: $name)
                        }
                        formCard(title: "Habit Type") {
                            Picker("Habit Type", selection: $selectedHabitType) {
                                Text("No type").tag("")
                                ForEach(["Weights", "Cardio", "Hybrid", "Hike", "Sports Training", "Swim", "Yoga", "Cycling", "Run", "Other"], id: \.self) { type in
                                    Text(type).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(themeManager.currentTheme.primary)
                        }
                        formCard(title: "Frequency") {
                            VStack(spacing: 0) {
                                ForEach(HabitFrequency.allCases, id: \.self) { freq in
                                    Button {
                                        frequency = freq
                                    } label: {
                                        HStack {
                                            Text(freq.label).foregroundColor(.primary)
                                            Spacer()
                                            if frequency == freq {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(themeManager.currentTheme.primary)
                                            }
                                        }
                                        .padding(.vertical, 10)
                                    }
                                    if freq != HabitFrequency.allCases.last {
                                        Divider()
                                    }
                                }
                            }
                        }
                        if frequency == .specificDays {
                            formCard(title: "Which Days") {
                                HStack(spacing: 8) {
                                    ForEach(days, id: \.self) { day in
                                        Button {
                                            if selectedDays.contains(day) {
                                                selectedDays.remove(day)
                                            } else {
                                                selectedDays.insert(day)
                                            }
                                        } label: {
                                            Text(day)
                                                .font(.caption)
                                                .frame(width: 36, height: 36)
                                                .background(selectedDays.contains(day) ? themeManager.currentTheme.primary : Color(.systemGray5))
                                                .foregroundColor(selectedDays.contains(day) ? .white : .primary)
                                                .clipShape(Circle())
                                        }
                                    }
                                }
                            }
                        }
                        if frequency == .weekly {
                            formCard(title: "Weekly Target") {
                                Stepper("\(weeklyTarget) times per week", value: $weeklyTarget, in: 1...7)
                            }
                        }
                        if frequency == .monthly {
                            formCard(title: "Monthly Target") {
                                Stepper("\(monthlyTarget) times per month", value: $monthlyTarget, in: 1...31)
                            }
                        }
                        formCard(title: "Daily Target") {
                            VStack(spacing: 10) {
                                Toggle("Set a target count", isOn: $hasTarget)
                                    .tint(themeManager.currentTheme.primary)
                                if hasTarget {
                                    Divider()
                                    Stepper("\(targetCount) times per day", value: $targetCount, in: 2...100)
                                }
                            }
                        }
                        formCard(title: "Link to Group (Optional)") {
                            VStack(spacing: 0) {
                                Button {
                                    selectedGroupId = nil
                                } label: {
                                    HStack {
                                        Text("No group").foregroundColor(.primary)
                                        Spacer()
                                        if selectedGroupId == nil {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(themeManager.currentTheme.primary)
                                        }
                                    }
                                    .padding(.vertical, 10)
                                }
                                if !userGroups.isEmpty {
                                    Divider()
                                }
                                ForEach(userGroups) { group in
                                    Button {
                                        selectedGroupId = group.id
                                    } label: {
                                        HStack {
                                            Text(group.name).foregroundColor(.primary)
                                            Spacer()
                                            if selectedGroupId == group.id {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(themeManager.currentTheme.primary)
                                            }
                                        }
                                        .padding(.vertical, 10)
                                    }
                                    if group.id != userGroups.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                        formCard(title: "Privacy") {
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle("Keep this habit private", isOn: $isPrivate)
                                    .tint(themeManager.currentTheme.primary)
                                Text(isPrivate
                                    ? "Friends will see you hit a streak but won't see the habit name."
                                    : "Friends will see your streak and habit name.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        formCard(title: "One-off") {
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle(isOn: $isOneOff) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("One-off event")
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                        Text("Appears once on the chosen date")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .tint(Color(red: 0.15, green: 0.55, blue: 0.38))
                                if isOneOff {
                                    Divider()
                                    DatePicker("Date", selection: $oneOffDate, displayedComponents: [.date])
                                        .datePickerStyle(.compact)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .task {
                guard let userId = appState.currentUser?.id else { return }
                do {
                    struct MemberRow: Decodable {
                        let group: AppGroup
                        enum CodingKeys: String, CodingKey {
                            case group = "groups"
                        }
                    }
                    let rows: [MemberRow] = try await supabase
                        .from("group_members")
                        .select("groups(*)")
                        .eq("user_id", value: userId.uuidString)
                        .execute()
                        .value
                    userGroups = rows.map { $0.group }
                } catch {
                    print("[AddHabitView] Failed to fetch groups: \(error)")
                }
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(themeManager.currentTheme.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        showVisibilityPrompt = true
                    }
                    .foregroundColor(name.isEmpty ? .secondary : themeManager.currentTheme.primary)
                    .disabled(name.isEmpty)
                }
            }
            .alert("Visible to friends?", isPresented: $showVisibilityPrompt) {
                Button("Yes") {
                    visibleToFriends = true
                    Task {
                        guard let userId = appState.currentUser?.id else { return }
                        await viewModel.createHabit(
                            name: name,
                            frequency: frequency,
                            daysOfWeek: frequency == .specificDays ? selectedDays.joined(separator: ",") : nil,
                            weeklyTarget: frequency == .weekly ? weeklyTarget : nil,
                            monthlyTarget: frequency == .monthly ? monthlyTarget : nil,
                            targetCount: hasTarget ? targetCount : nil,
                            groupId: selectedGroupId,
                            userId: userId,
                            isPrivate: isPrivate,
                            visibleToFriends: visibleToFriends,
                            targetDate: isOneOff ? oneOffDate : nil
                        )
                        dismiss()
                    }
                }
                Button("No") {
                    Task {
                        guard let userId = appState.currentUser?.id else { return }
                        await viewModel.createHabit(
                            name: name,
                            frequency: frequency,
                            daysOfWeek: frequency == .specificDays ? selectedDays.joined(separator: ",") : nil,
                            weeklyTarget: frequency == .weekly ? weeklyTarget : nil,
                            monthlyTarget: frequency == .monthly ? monthlyTarget : nil,
                            targetCount: hasTarget ? targetCount : nil,
                            groupId: selectedGroupId,
                            userId: userId,
                            isPrivate: isPrivate,
                            visibleToFriends: false,
                            targetDate: isOneOff ? oneOffDate : nil
                        )
                        dismiss()
                    }
                }
            } message: {
                Text("Do you want this habit to appear in your friends' feed?")
            }
        }
    }
}
