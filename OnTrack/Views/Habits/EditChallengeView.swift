import SwiftUI

struct EditChallengeView: View {
    let challenge: Challenge
    let viewModel: ChallengeViewModel
    let onDismiss: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager

    @State private var title: String
    @State private var description: String
    @State private var goalType: String
    @State private var goalTarget: Double
    @State private var goalUnit: String
    @State private var frequency: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var acceptBy: Date

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
    private let weekDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    init(challenge: Challenge, viewModel: ChallengeViewModel, onDismiss: @escaping () -> Void) {
        self.challenge = challenge
        self.viewModel = viewModel
        self.onDismiss = onDismiss
        _title = State(initialValue: challenge.title)
        _description = State(initialValue: challenge.description ?? "")
        _goalType = State(initialValue: challenge.goalType)
        _goalTarget = State(initialValue: challenge.goalTarget)
        _goalUnit = State(initialValue: challenge.goalUnit ?? "")
        _frequency = State(initialValue: challenge.frequency ?? "weekly")
        _startDate = State(initialValue: challenge.startDate ?? Date())
        _endDate = State(initialValue: challenge.endDate ?? Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date())
        _acceptBy = State(initialValue: challenge.acceptBy)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {

                    // CHALLENGE DETAILS
                    formCard(title: "CHALLENGE DETAILS") {
                        VStack(spacing: 10) {
                            OnTrackTextField(placeholder: "Challenge title", text: $title)
                            OnTrackTextField(placeholder: "What's the goal? (optional)", text: $description)
                        }
                    }

                    // GOAL
                    formCard(title: "GOAL") {
                        VStack(spacing: 14) {
                            Picker("Goal Type", selection: $goalType) {
                                Text("Habit").tag("habit")
                                Text("Session").tag("session")
                            }
                            .pickerStyle(.segmented)
                            .tint(gold)

                            Stepper(
                                "\(Int(goalTarget)) \(goalUnit.isEmpty ? "reps" : goalUnit)",
                                value: $goalTarget,
                                in: 1...999
                            )
                            .foregroundStyle(.white)

                            OnTrackTextField(placeholder: "Unit e.g. km, sessions, reps", text: $goalUnit)

                            Picker("Frequency", selection: $frequency) {
                                Text("Daily").tag("daily")
                                Text("Weekly").tag("weekly")
                                Text("Monthly").tag("monthly")
                            }
                            .pickerStyle(.segmented)
                            .tint(gold)
                        }
                    }

                    // DATES
                    formCard(title: "DATES") {
                        VStack(spacing: 12) {
                            DatePicker(
                                "Accept by",
                                selection: $acceptBy,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .foregroundStyle(.white)
                            .accentColor(gold)

                            Divider().background(Color.white.opacity(0.1))

                            DatePicker(
                                "Starts",
                                selection: $startDate,
                                displayedComponents: [.date]
                            )
                            .foregroundStyle(.white)
                            .accentColor(gold)

                            Divider().background(Color.white.opacity(0.1))

                            DatePicker(
                                "Ends",
                                selection: $endDate,
                                displayedComponents: [.date]
                            )
                            .foregroundStyle(.white)
                            .accentColor(gold)
                        }
                    }

                    // SAVE BUTTON
                    Button {
                        Task {
                            await viewModel.updateChallenge(
                                challenge,
                                title: title,
                                description: description,
                                goalType: goalType,
                                goalTarget: goalTarget,
                                goalUnit: goalUnit,
                                frequency: frequency,
                                startDate: startDate,
                                endDate: endDate,
                                acceptBy: acceptBy
                            )
                            onDismiss()
                        }
                    } label: {
                        Text("Save Changes")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundStyle(Color(red: 0.10, green: 0.07, blue: 0.0))
                    }
                    .background(RoundedRectangle(cornerRadius: 12).fill(gold))
                    .disabled(title.isEmpty)
                    .opacity(title.isEmpty ? 0.4 : 1.0)
                    .padding(.horizontal)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(themeManager.backgroundColour())
            .navigationTitle("Edit Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onDismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func formCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal, 4)
            content()
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
                )
        }
    }
}
