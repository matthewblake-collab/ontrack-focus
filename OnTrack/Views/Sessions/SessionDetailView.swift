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
                    Text("DETAILS")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.4)
                        .foregroundStyle(themeManager.currentTheme.primary.opacity(0.7))
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 12) {
                        if let description = session.description, !description.isEmpty {
                            Text(description)
                                .foregroundStyle(.white)
                        }
                        if let location = session.location, !location.isEmpty {
                            Label(location, systemImage: "mappin.and.ellipse")
                                .foregroundStyle(.white)
                        }
                        if let proposedAt = session.proposedAt {
                            Label(proposedAt.formatted(date: .complete, time: .shortened),
                                  systemImage: "calendar")
                                .foregroundStyle(.white)
                        }
                        HStack {
                            Text("Status")
                                .foregroundStyle(.white)
                            Spacer()
                            StatusBadge(status: session.status)
                        }
                        if let rule = session.recurrenceRule, rule != "none" {
                            Label("Repeats \(rule.capitalized)", systemImage: "repeat")
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(16)
                    .background(Color(red: 0.05, green: 0.08, blue: 0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(themeManager.currentTheme.primary.opacity(0.25), lineWidth: 7))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(themeManager.currentTheme.primary.opacity(0.75), lineWidth: 1.5))
                    .padding(.horizontal, 16)
                }

                // RSVP SECTION
                if session.status == "upcoming", let userId = appState.currentUser?.id {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("RSVP")
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(1.4)
                            .foregroundStyle(themeManager.currentTheme.primary.opacity(0.7))
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        RSVPPickerView(sessionId: session.id, userId: userId)
                            .padding(16)
                            .background(Color(red: 0.05, green: 0.08, blue: 0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(themeManager.currentTheme.primary.opacity(0.25), lineWidth: 7))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(themeManager.currentTheme.primary.opacity(0.75), lineWidth: 1.5))
                            .padding(.horizontal, 16)
                    }
                }

                // AVAILABILITY SECTION
                if session.status == "upcoming" {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AVAILABILITY")
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(1.4)
                            .foregroundStyle(themeManager.currentTheme.primary.opacity(0.7))
                            .padding(.horizontal, 20)
                            .padding(.top, 20)

                        NavigationLink(destination: AvailabilityView(session: session)) {
                            HStack {
                                Label("View & Add Availability", systemImage: "clock")
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            .padding(16)
                            .background(Color(red: 0.05, green: 0.08, blue: 0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(themeManager.currentTheme.primary.opacity(0.25), lineWidth: 7))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(themeManager.currentTheme.primary.opacity(0.75), lineWidth: 1.5))
                            .padding(.horizontal, 16)
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
                                .foregroundStyle(reminderSet ? Color(red: 0.08, green: 0.35, blue: 0.45) : .white.opacity(0.6))
                            Text(reminderSet ? "Reminder Set" : "Set Reminder")
                                .foregroundStyle(reminderSet ? Color(red: 0.08, green: 0.35, blue: 0.45) : .white)
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
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.05, green: 0.08, blue: 0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(themeManager.currentTheme.primary.opacity(0.25), lineWidth: 7))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(themeManager.currentTheme.primary.opacity(0.75), lineWidth: 1.5))
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }

                // COMMENTS SECTION
                VStack(alignment: .leading, spacing: 12) {
                    Text("COMMENTS")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.4)
                        .foregroundStyle(themeManager.currentTheme.primary.opacity(0.7))
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    NavigationLink(destination: CommentsView(session: session)) {
                        HStack {
                            Label("View Comments", systemImage: "bubble.left.and.bubble.right")
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(16)
                        .background(Color(red: 0.05, green: 0.08, blue: 0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(themeManager.currentTheme.primary.opacity(0.25), lineWidth: 7))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(themeManager.currentTheme.primary.opacity(0.75), lineWidth: 1.5))
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)
                }

                // ATTENDANCE SECTION
                VStack(alignment: .leading, spacing: 12) {
                    Text("ATTENDANCE")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.4)
                        .foregroundStyle(themeManager.currentTheme.primary.opacity(0.7))
                        .padding(.horizontal, 20)
                        .padding(.top, 20)

                    NavigationLink(destination: AttendanceView(session: session, group: group)) {
                        HStack {
                            Label("View Attendance", systemImage: "person.fill.checkmark")
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(16)
                        .background(Color(red: 0.05, green: 0.08, blue: 0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(themeManager.currentTheme.primary.opacity(0.25), lineWidth: 7))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(themeManager.currentTheme.primary.opacity(0.75), lineWidth: 1.5))
                        .padding(.horizontal, 16)
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
                                .padding(16)
                                .background(Color(red: 0.05, green: 0.08, blue: 0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.red.opacity(0.25), lineWidth: 7))
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.red.opacity(0.75), lineWidth: 1.5))
                                .padding(.horizontal, 16)
                        }

                        if session.seriesId != nil {
                            Button(role: .destructive) {
                                showCancelSeriesConfirm = true
                            } label: {
                                Label("Cancel All Remaining Sessions", systemImage: "xmark.circle.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding(16)
                                    .background(Color(red: 0.05, green: 0.08, blue: 0.10))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.red.opacity(0.25), lineWidth: 7))
                                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.red.opacity(0.75), lineWidth: 1.5))
                                    .padding(.horizontal, 16)
                            }
                            .padding(.top, 1)
                        }
                    }
                    .padding(.top, 20)
                }
            }
        }
        .background {
            GeometryReader { geo in
                Image(themeManager.currentBackgroundImage)
                    .resizable()
                    .scaledToFill()
                    .grayscale(1.0)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.67),
                        Color.black.opacity(0.37),
                        Color.clear
                    ]),
                    startPoint: .top,
                    endPoint: .center
                )
            }
            .ignoresSafeArea()
        }
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
