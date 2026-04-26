import SwiftUI

struct AttendanceView: View {
    let session: AppSession
    let group: AppGroup
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var viewModel = AttendanceViewModel()

    var isCreator: Bool {
        session.createdBy == appState.currentUser?.id
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("\(viewModel.attendedCount)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                        Text("Attended")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 4) {
                        Text("\(max(0, viewModel.absentCount))")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.red)
                        Text("Absent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 4) {
                        Text("\(viewModel.members.count)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                        Text("Total")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(themeManager.cardColour())

            Section("Members") {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    ForEach(viewModel.members) { member in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.profileName(for: member.userId))
                                    .font(.subheadline)
                                Text(member.role.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isCreator {
                                Toggle("", isOn: Binding(
                                    get: { viewModel.attendanceStatus(for: member.userId) ?? false },
                                    set: { newValue in
                                        Task {
                                            guard let markerId = appState.currentUser?.id else { return }
                                            await viewModel.markAttendance(
                                                sessionId: session.id,
                                                userId: member.userId,
                                                attended: newValue,
                                                markedBy: markerId,
                                                groupId: group.id
                                            )
                                        }
                                    }
                                ))
                                .labelsHidden()
                            } else {
                                if let attended = viewModel.attendanceStatus(for: member.userId) {
                                    Image(systemName: attended ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(attended ? .green : .red)
                                } else {
                                    Image(systemName: "minus.circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .listRowBackground(themeManager.cardColour())

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                .listRowBackground(themeManager.cardColour())
            }
        }
        .themedList(themeManager)
        .navigationTitle("Attendance")
        .task {
            await viewModel.fetchAttendance(sessionId: session.id, groupId: group.id)
        }
    }
}
