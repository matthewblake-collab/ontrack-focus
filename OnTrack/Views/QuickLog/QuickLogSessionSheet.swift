import SwiftUI

/// Quick-Log "session / workout completed" mini-sheet. Pick a workout type (+ optional
/// duration) and log it. If a matching habit exists, the log goes to that habit so
/// streaks count; otherwise it lands in `quick_logs`. If a group session is scheduled
/// today, a one-tap "Mark attended" shortcut is surfaced at the top.
struct QuickLogSessionSheet: View {
    @ObservedObject var habitVM: HabitViewModel
    let quickLogVM: QuickLogViewModel
    let userId: UUID?
    let onComplete: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var groupVM = GroupViewModel()
    @State private var attendanceVM = AttendanceViewModel()
    @State private var selectedType: QuickLogViewModel.WorkoutType?
    @State private var durationText = ""
    @State private var statusMessage: String?

    private let cardColor = Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92)
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    private var todaySession: AppSession? {
        groupVM.nextSessions.values.first { s in
            guard let p = s.proposedAt else { return false }
            return Calendar.current.isDateInToday(p)
        }
    }

    private func matchedHabit(for type: QuickLogViewModel.WorkoutType) -> Habit? {
        guard type != .other else { return nil }
        let needle = type.rawValue.lowercased()
        return habitVM.habits.first { $0.name.lowercased().contains(needle) }
    }

    var body: some View {
        ZStack {
            themeManager.backgroundColour().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Log a session")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.top, 8)

                    if let session = todaySession, let userId, let gid = session.groupId {
                        Button {
                            Task {
                                await attendanceVM.markAttendance(sessionId: session.id, userId: userId, attended: true, markedBy: userId, groupId: gid)
                                if let err = attendanceVM.errorMessage {
                                    statusMessage = err
                                } else {
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                    onComplete()
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(themeManager.currentTheme.primary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(session.title) — today")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text("Tap to mark attended")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                                Spacer()
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(cardColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }

                    Text("What did you do?")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(QuickLogViewModel.WorkoutType.allCases) { type in
                            Button {
                                selectedType = type
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 20))
                                    Text(type.rawValue)
                                        .font(.caption2.weight(.semibold))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(selectedType == type ? themeManager.currentTheme.primary : cardColor)
                                .foregroundStyle(selectedType == type ? .white : .white.opacity(0.75))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    TextField("", text: $durationText, prompt: Text("Duration in minutes (optional)").foregroundColor(.white.opacity(0.4)))
                        .keyboardType(.numberPad)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(cardColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button {
                        guard let type = selectedType, let userId else { return }
                        Task {
                            let dur = Int(durationText.trimmingCharacters(in: .whitespaces))
                            let ok = await quickLogVM.logWorkout(
                                type: type,
                                durationMinutes: dur,
                                userId: userId,
                                matchedHabit: matchedHabit(for: type),
                                habitVM: habitVM
                            )
                            if ok {
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                onComplete()
                            } else {
                                statusMessage = quickLogVM.errorMessage ?? "Couldn't log that — try again."
                            }
                        }
                    } label: {
                        Group {
                            if quickLogVM.isWorking {
                                ProgressView().tint(.white)
                            } else if let type = selectedType {
                                if let h = matchedHabit(for: type) {
                                    Text("Log \(type.rawValue) · marks “\(h.name)” done")
                                } else {
                                    Text("Log \(type.rawValue)")
                                }
                            } else {
                                Text("Pick a type")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundStyle(.white)
                        .background(selectedType == nil ? Color.gray.opacity(0.3) : themeManager.currentTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedType == nil || quickLogVM.isWorking)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            guard let userId else { return }
            await groupVM.fetchGroups()
            await habitVM.fetchHabits()
            await habitVM.fetchLogs(for: userId)
        }
    }
}
