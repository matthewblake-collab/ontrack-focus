import SwiftUI

struct CreateChallengeView: View {
    @Bindable var viewModel: ChallengeViewModel
    let userId: UUID
    let friends: [FriendProfile]
    let groups: [AppGroup]
    let onDismiss: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager

    @State private var selectedDays: [String] = []

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
    private let weekDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {

                    // 1. CHALLENGE DETAILS
                    formCard(title: "CHALLENGE DETAILS") {
                        VStack(spacing: 10) {
                            OnTrackTextField(placeholder: "Challenge title", text: $viewModel.newTitle)
                            OnTrackTextField(placeholder: "What's the goal? (optional)", text: $viewModel.newDescription)
                        }
                    }

                    // 2. GOAL
                    formCard(title: "GOAL") {
                        VStack(spacing: 14) {
                            Picker("Goal Type", selection: $viewModel.newGoalType) {
                                Text("Habit").tag("habit")
                                Text("Session").tag("session")
                            }
                            .pickerStyle(.segmented)
                            .tint(gold)

                            Stepper(
                                "\(Int(viewModel.newGoalTarget)) \(viewModel.newGoalUnit.isEmpty ? "reps" : viewModel.newGoalUnit)",
                                value: $viewModel.newGoalTarget,
                                in: 1...999
                            )
                            .foregroundStyle(.white)

                            OnTrackTextField(placeholder: "Unit e.g. km, sessions, reps", text: $viewModel.newGoalUnit)

                            Picker("Frequency", selection: $viewModel.newFrequency) {
                                Text("Daily").tag("daily")
                                Text("Weekly").tag("weekly")
                                Text("Monthly").tag("monthly")
                            }
                            .pickerStyle(.segmented)
                            .tint(gold)

                            if viewModel.newFrequency == "weekly" {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(weekDays, id: \.self) { day in
                                            Button(day) {
                                                if selectedDays.contains(day) {
                                                    selectedDays.removeAll { $0 == day }
                                                } else {
                                                    selectedDays.append(day)
                                                }
                                            }
                                            .font(.caption.bold())
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(selectedDays.contains(day) ? gold : Color.white.opacity(0.08))
                                            .foregroundColor(selectedDays.contains(day) ? .black : .white)
                                            .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 3. DATES
                    formCard(title: "DATES") {
                        VStack(spacing: 12) {
                            DatePicker(
                                "Accept by",
                                selection: $viewModel.newAcceptBy,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .foregroundStyle(.white)
                            .accentColor(gold)

                            Divider().background(Color.white.opacity(0.1))

                            DatePicker(
                                "Starts",
                                selection: $viewModel.newStartDate,
                                displayedComponents: [.date]
                            )
                            .foregroundStyle(.white)
                            .accentColor(gold)

                            Divider().background(Color.white.opacity(0.1))

                            DatePicker(
                                "Ends",
                                selection: $viewModel.newEndDate,
                                displayedComponents: [.date]
                            )
                            .foregroundStyle(.white)
                            .accentColor(gold)
                        }
                    }

                    // 4. INVITE FRIENDS
                    formCard(title: "INVITE FRIENDS") {
                        DisclosureGroup(
                            isExpanded: .constant(true),
                            content: {
                                if friends.isEmpty {
                                    Text("No friends yet — invite some first")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                        .padding(.top, 8)
                                } else {
                                    VStack(spacing: 0) {
                                        ForEach(friends) { friend in
                                            let isSelected = viewModel.selectedInviteeIds.contains(friend.id)
                                            Button {
                                                if isSelected {
                                                    viewModel.selectedInviteeIds.removeAll { $0 == friend.id }
                                                } else {
                                                    viewModel.selectedInviteeIds.append(friend.id)
                                                }
                                            } label: {
                                                HStack {
                                                    Text(friend.displayName ?? "Unknown")
                                                        .font(.subheadline)
                                                        .foregroundStyle(.white)
                                                    Spacer()
                                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                        .foregroundStyle(isSelected ? gold : Color.white.opacity(0.3))
                                                        .font(.title3)
                                                }
                                                .padding(.vertical, 10)
                                            }
                                            .buttonStyle(.plain)
                                            if friend.id != friends.last?.id {
                                                Divider().background(Color.white.opacity(0.1))
                                            }
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            },
                            label: {
                                Text("Invite Friends (\(viewModel.selectedInviteeIds.count) selected)")
                                    .font(.subheadline)
                                    .foregroundStyle(gold)
                            }
                        )
                        .accentColor(gold)
                    }

                    // 5. INVITE GROUP
                    if !groups.isEmpty {
                        formCard(title: "INVITE GROUP (OPTIONAL)") {
                            VStack(spacing: 0) {
                                ForEach(groups) { group in
                                    let isSelected = viewModel.newGroupId == group.id
                                    Button {
                                        viewModel.newGroupId = isSelected ? nil : group.id
                                    } label: {
                                        HStack {
                                            Text(group.name)
                                                .font(.subheadline)
                                                .foregroundStyle(.white)
                                            Spacer()
                                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(isSelected ? gold : Color.white.opacity(0.3))
                                                .font(.title3)
                                        }
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)
                                    if group.id != groups.last?.id {
                                        Divider().background(Color.white.opacity(0.1))
                                    }
                                }

                                if viewModel.newGroupId != nil {
                                    HStack(spacing: 6) {
                                        Image(systemName: "info.circle")
                                            .font(.caption)
                                            .foregroundStyle(gold.opacity(0.8))
                                        Text("All group members will be invited")
                                            .font(.caption)
                                            .foregroundStyle(gold.opacity(0.8))
                                    }
                                    .padding(.top, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }

                    // 6. CREATE BUTTON
                    Button {
                        Task {
                            await viewModel.createChallenge(createdBy: userId)
                            onDismiss()
                        }
                    } label: {
                        Text("Create Challenge")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundStyle(Color(red: 0.10, green: 0.07, blue: 0.0))
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(gold)
                    )
                    .disabled(viewModel.newTitle.isEmpty)
                    .opacity(viewModel.newTitle.isEmpty ? 0.4 : 1.0)
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
            .navigationTitle("Create Challenge")
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
