import SwiftUI

struct CreateSingleSessionView: View {
    @Bindable var viewModel: SessionViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var enableReminder = true
    @State private var reminderMinutes = 30

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    SectionCard(title: "Session Details") {
                        VStack(spacing: 12) {
                            OnTrackTextField(placeholder: "Title", text: $viewModel.newTitle)
                            OnTrackTextField(placeholder: "Description (optional)", text: $viewModel.newDescription)
                            OnTrackTextField(placeholder: "Location (optional)", text: $viewModel.newLocation)
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

                    SectionCard(title: "Date & Time") {
                        DatePicker("Start Date",
                                   selection: $viewModel.newProposedAt,
                                   displayedComponents: [.date, .hourAndMinute])
                    }

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

                    Button {
                        Task {
                            guard let userId = appState.currentUser?.id else { return }
                            let createdSession = await viewModel.createPersonalSession(userId: userId)
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
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
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
