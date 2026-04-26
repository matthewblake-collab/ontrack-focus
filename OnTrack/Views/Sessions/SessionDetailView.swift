import SwiftUI

struct SessionDetailView: View {
    let session: AppSession
    let group: AppGroup
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var sessionViewModel = SessionViewModel()
    @State private var showEditSession = false
    @State private var showCancelSeriesConfirm = false
    @State private var showReminderOptions = false
    @State private var reminderSet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // DETAILS SECTION
                VStack(alignment: .leading, spacing: 12) {
                    Text("Details")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 12) {
                        if let description = session.description, !description.isEmpty {
                            Text(description)
                        }
                        if let location = session.location, !location.isEmpty {
                            Label(location, systemImage: "mappin.and.ellipse")
                        }
                        if let proposedAt = session.proposedAt {
                            Label(proposedAt.formatted(date: .complete, time: .shortened),
                                  systemImage: "calendar")
                        }
                        HStack {
                            Text("Status")
                            Spacer()
                            StatusBadge(status: session.status)
                        }
                        if let rule = session.recurrenceRule, rule != "none" {
                            Label("Repeats \(rule.capitalized)", systemImage: "repeat")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                }

                // RSVP SECTION
                if session.status == "upcoming", let userId = appState.currentUser?.id {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("RSVP")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 20)

                        RSVPPickerView(sessionId: session.id, userId: userId)
                            .padding()
                            .background(Color(.systemBackground))
                    }
                }

                // AVAILABILITY SECTION
                if session.status == "upcoming" {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Availability")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 20)

                        NavigationLink(destination: AvailabilityView(session: session)) {
                            HStack {
                                Label("View & Add Availability", systemImage: "clock")
                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemBackground))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // REMINDER SECTION
                if session.status == "upcoming" {
                    Button {
                        showReminderOptions = true
                    } label: {
                        HStack {
                            Image(systemName: reminderSet ? "bell.fill" : "bell")
                                .foregroundStyle(reminderSet ? Color(red: 0.08, green: 0.35, blue: 0.45) : .secondary)
                            Text(reminderSet ? "Reminder Set" : "Set Reminder")
                                .foregroundStyle(reminderSet ? Color(red: 0.08, green: 0.35, blue: 0.45) : .primary)
                        }
                    }
                    .confirmationDialog("Set Reminder", isPresented: $showReminderOptions) {
                        Button("1 hour before") {
                            NotificationManager.shared.scheduleSessionReminder(session: session, minutesBefore: 60)
                            reminderSet = true
                        }
                        Button("30 minutes before") {
                            NotificationManager.shared.scheduleSessionReminder(session: session, minutesBefore: 30)
                            reminderSet = true
                        }
                        Button("15 minutes before") {
                            NotificationManager.shared.scheduleSessionReminder(session: session, minutesBefore: 15)
                            reminderSet = true
                        }
                        if reminderSet {
                            Button("Cancel Reminder", role: .destructive) {
                                NotificationManager.shared.cancelSessionReminder(sessionId: session.id)
                                reminderSet = false
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .padding(.top, 20)
                }

                // COMMENTS SECTION
                VStack(alignment: .leading, spacing: 12) {
                    Text("Comments")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 20)

                    NavigationLink(destination: CommentsView(session: session)) {
                        HStack {
                            Label("View Comments", systemImage: "bubble.left.and.bubble.right")
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                    }
                    .buttonStyle(.plain)
                }

                // ATTENDANCE SECTION
                VStack(alignment: .leading, spacing: 12) {
                    Text("Attendance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 20)

                    NavigationLink(destination: AttendanceView(session: session, group: group)) {
                        HStack {
                            Label("View Attendance", systemImage: "person.fill.checkmark")
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground))
                    }
                    .buttonStyle(.plain)
                }

                // CANCEL SECTION
                if session.createdBy == appState.currentUser?.id && session.status == "upcoming" {
                    VStack(spacing: 0) {
                        Button(role: .destructive) {
                            Task {
                                await sessionViewModel.cancelSession(sessionId: session.id, groupId: group.id)
                                dismiss()
                            }
                        } label: {
                            Label("Cancel This Session", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemBackground))
                        }

                        if session.seriesId != nil {
                            Button(role: .destructive) {
                                showCancelSeriesConfirm = true
                            } label: {
                                Label("Cancel All Remaining Sessions", systemImage: "xmark.circle.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemBackground))
                            }
                            .padding(.top, 1)
                        }
                    }
                    .padding(.top, 20)
                }
            }
        }
        .background(themeManager.backgroundColour())
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if session.createdBy == appState.currentUser?.id && session.status == "upcoming" {
                    Button("Edit") {
                        showEditSession = true
                    }
                    .foregroundStyle(themeManager.currentTheme.primary)
                }
            }
        }
        .confirmationDialog("Cancel All Sessions", isPresented: $showCancelSeriesConfirm) {
            Button("Cancel All Remaining Sessions", role: .destructive) {
                Task {
                    if let seriesId = session.seriesId {
                        await sessionViewModel.cancelSeries(seriesId: seriesId, groupId: group.id)
                        dismiss()
                    }
                }
            }
            Button("Keep Sessions", role: .cancel) {}
        } message: {
            Text("This will cancel all upcoming sessions in this series.")
        }
        .sheet(isPresented: $showEditSession) {
            EditSessionView(session: session, group: group)
                .environmentObject(appState)
                .environmentObject(themeManager)
        }
    }
}
