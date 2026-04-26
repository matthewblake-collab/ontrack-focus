import SwiftUI

struct EditSupplementView: View {
    let supplement: Supplement
    @ObservedObject var viewModel: SupplementViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var inProtocol: Bool = false
    @State private var showDoseCalculator = false
    @State private var recurrenceRule: SupplementRecurrence = .daily
    @State private var recurrenceEndDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var customDates: [Date] = []

    private let unitOptions = ["g", "mg", "ml", "mcg", "IU", "capsules", "tablets", "drops", "tsp", "tbsp"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    formCard(title: "Supplement Details") {
                        VStack(spacing: 12) {
                            OnTrackTextField(placeholder: "Name", text: $viewModel.newName)

                            Button { showDoseCalculator = true } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "eyedropper.halffull").font(.subheadline)
                                    Text("Calculate dose").font(.subheadline).fontWeight(.medium)
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

                            HStack(spacing: 12) {
                                TextField("Stock quantity", text: $viewModel.newStockQuantity)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
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

                    formCard(title: "Protocol") {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("In Protocol", isOn: $inProtocol)
                                .tint(themeManager.currentTheme.primary)
                            Text(inProtocol
                                ? "This supplement appears in your daily actions."
                                : "Saved to My Stack only — not driving daily actions.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

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
                            viewModel.newDaysOfWeek = recurrenceRule.storageValue(customDates: customDates, endDate: recurrenceEndDate)
                            await viewModel.updateSupplement(supplement: supplement, userId: userId)
                            await viewModel.updateProtocol(
                                supplement: supplement,
                                inProtocol: inProtocol,
                                timing: viewModel.newTiming,
                                daysOfWeek: viewModel.newDaysOfWeek,
                                reminderEnabled: viewModel.newReminderEnabled,
                                userId: userId
                            )
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView().tint(.white).frame(maxWidth: .infinity).padding()
                        } else {
                            Text("Save Changes")
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
                .padding(.vertical)
            }
            .background(themeManager.backgroundColour())
            .sheet(isPresented: $showDoseCalculator) {
                SupplementDoseCalculatorView(resultDose: $viewModel.newDoseAmount)
            }
            .onAppear {
                viewModel.newName = supplement.name
                viewModel.newDoseAmount = supplement.doseAmount.map { String($0) } ?? ""
                viewModel.newDoseUnits = supplement.doseUnits ?? "g"
                viewModel.newNotes = supplement.notes ?? ""
                viewModel.newStockQuantity = supplement.stockQuantity.map { String($0) } ?? ""
                viewModel.newStockUnits = supplement.stockUnits ?? ""
                viewModel.newTiming = SupplementTiming(rawValue: supplement.timing) ?? .morning
                viewModel.newDaysOfWeek = supplement.daysOfWeek
                viewModel.newReminderEnabled = supplement.reminderEnabled
                viewModel.newStartDateEnabled = supplement.startDate != nil
                if let s = supplement.startDate {
                    let f = DateFormatter()
                    f.dateFormat = "yyyy-MM-dd"
                    viewModel.newStartDate = f.date(from: s) ?? Date()
                }
                inProtocol = supplement.inProtocol

                // Parse existing daysOfWeek into recurrence state
                let daysOfWeek = supplement.daysOfWeek
                if daysOfWeek == "everyday" || daysOfWeek.isEmpty {
                    recurrenceRule = .daily
                } else if daysOfWeek == "once" {
                    recurrenceRule = .once
                } else if daysOfWeek.hasPrefix("weekly") {
                    recurrenceRule = .weekly
                    if let ts = daysOfWeek.components(separatedBy: "|").last, let interval = TimeInterval(ts) {
                        recurrenceEndDate = Date(timeIntervalSince1970: interval)
                    }
                } else if daysOfWeek.hasPrefix("fortnightly") {
                    recurrenceRule = .fortnightly
                    if let ts = daysOfWeek.components(separatedBy: "|").last, let interval = TimeInterval(ts) {
                        recurrenceEndDate = Date(timeIntervalSince1970: interval)
                    }
                } else if daysOfWeek.hasPrefix("monthly") {
                    recurrenceRule = .monthly
                    if let ts = daysOfWeek.components(separatedBy: "|").last, let interval = TimeInterval(ts) {
                        recurrenceEndDate = Date(timeIntervalSince1970: interval)
                    }
                } else if daysOfWeek.hasPrefix("custom") {
                    recurrenceRule = .custom
                    let parts = daysOfWeek.components(separatedBy: "|")
                    if parts.count > 1 {
                        customDates = parts[1].components(separatedBy: ",").compactMap {
                            TimeInterval($0).map { Date(timeIntervalSince1970: $0) }
                        }
                    }
                } else {
                    recurrenceRule = .daily
                }

                if let ct = supplement.customTime {
                    let f = DateFormatter()
                    f.dateFormat = "HH:mm"
                    viewModel.newCustomTime = f.date(from: ct) ?? Date()
                }
            }
            .navigationTitle("Edit Supplement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func formCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).padding(.horizontal)
            VStack(alignment: .leading, spacing: 0) {
                content().padding()
            }
            .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
}
