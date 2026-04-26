import SwiftUI

struct SessionListView: View {
    let group: AppGroup
    @State private var viewModel = SessionViewModel()
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showCreateSession = false
    @State private var showAll = false
    @State private var expandedSeries: Set<UUID> = []
    @State private var searchText = ""
    @State private var filterStatus: String = "all"
    @State private var sessionToCancel: AppSession? = nil
    @State private var selectedTypeFilter: String = ""

    var filteredSessions: [AppSession] {
        var sessions = viewModel.sessions

        if !showAll {
            sessions = sessions.filter { $0.status == "upcoming" }
        }

        if !searchText.isEmpty {
            sessions = sessions.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                ($0.location ?? "").localizedCaseInsensitiveContains(searchText) ||
                ($0.description ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }

        if filterStatus != "all" {
            sessions = sessions.filter { $0.status == filterStatus }
        }

        if !selectedTypeFilter.isEmpty {
            sessions = sessions.filter { $0.sessionType == selectedTypeFilter }
        }

        return sessions
    }

    var standaloneSessions: [AppSession] {
        filteredSessions.filter { $0.seriesId == nil }
    }

    var seriesGroups: [UUID: [AppSession]] {
        var groups: [UUID: [AppSession]] = [:]
        for session in filteredSessions {
            if let seriesId = session.seriesId {
                groups[seriesId, default: []].append(session)
            }
        }
        return groups
    }

    var sortedSeriesIds: [UUID] {
        seriesGroups.keys.sorted { a, b in
            let aFirst = seriesGroups[a]?.first?.proposedAt ?? Date.distantFuture
            let bFirst = seriesGroups[b]?.first?.proposedAt ?? Date.distantFuture
            return aFirst < bFirst
        }
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else {
                List {
                    // TYPE FILTER CHIPS
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(label: "All", isSelected: selectedTypeFilter.isEmpty) {
                                    selectedTypeFilter = ""
                                }
                                ForEach(SessionViewModel.sessionTypes, id: \.self) { type in
                                    FilterChip(label: type, isSelected: selectedTypeFilter == type) {
                                        selectedTypeFilter = selectedTypeFilter == type ? "" : type
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                    // FILTER CONTROLS
                    Section {
                        Toggle("Show cancelled & past", isOn: $showAll)
                            .font(.subheadline)

                        if showAll {
                            Picker("Filter", selection: $filterStatus) {
                                Text("All").tag("all")
                                Text("Upcoming").tag("upcoming")
                                Text("Completed").tag("completed")
                                Text("Cancelled").tag("cancelled")
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .listRowBackground(themeManager.cardColour())

                    if filteredSessions.isEmpty {
                        Section {
                            VStack(spacing: 12) {
                                Image(systemName: searchText.isEmpty ? "calendar.badge.plus" : "magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                                Text(searchText.isEmpty ? "No sessions found" : "No results for \"\(searchText)\"")
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        .listRowBackground(themeManager.cardColour())
                    } else {
                        // STANDALONE SESSIONS
                        ForEach(standaloneSessions) { session in
                            NavigationLink(destination: SessionDetailView(session: session, group: group)) {
                                SessionRowView(session: session)
                            }
                            .listRowBackground(themeManager.cardColour())
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if session.createdBy == appState.currentUser?.id && session.status == "upcoming" {
                                    Button(role: .destructive) {
                                        sessionToCancel = session
                                    } label: {
                                        Label("Cancel", systemImage: "xmark.circle")
                                    }
                                }
                            }
                        }

                        // SERIES GROUPS
                        ForEach(sortedSeriesIds, id: \.self) { seriesId in
                            if let sessions = seriesGroups[seriesId], let first = sessions.first {
                                Section {
                                    Button {
                                        if expandedSeries.contains(seriesId) {
                                            expandedSeries.remove(seriesId)
                                        } else {
                                            expandedSeries.insert(seriesId)
                                        }
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "repeat")
                                                        .font(.caption)
                                                        .foregroundStyle(.blue)
                                                    Text(first.recurrenceRule?.capitalized ?? "Recurring")
                                                        .font(.caption)
                                                        .foregroundStyle(.blue)
                                                }
                                                Text(first.title)
                                                    .font(.headline)
                                                    .foregroundStyle(.primary)
                                                Text("\(sessions.count) sessions · next \(nextUpcoming(in: sessions))")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: expandedSeries.contains(seriesId) ? "chevron.up" : "chevron.down")
                                                .foregroundStyle(.secondary)
                                                .font(.caption)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.plain)
                                    .listRowBackground(themeManager.cardColour())

                                    if expandedSeries.contains(seriesId) {
                                        ForEach(sessions) { session in
                                            NavigationLink(destination: SessionDetailView(session: session, group: group)) {
                                                SessionRowView(session: session)
                                                    .padding(.leading, 12)
                                            }
                                            .listRowBackground(themeManager.cardColour())
                                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                                if session.createdBy == appState.currentUser?.id && session.status == "upcoming" {
                                                    Button(role: .destructive) {
                                                        sessionToCancel = session
                                                    } label: {
                                                        Label("Cancel", systemImage: "xmark.circle")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                .listRowBackground(themeManager.cardColour())
                            }
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search sessions...")
                .listStyle(.insetGrouped)
                .themedList(themeManager)
            }
        }
        .navigationTitle("Sessions")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateSession = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await viewModel.fetchSessions(groupId: group.id)
        }
        .sheet(isPresented: $showCreateSession) {
            CreateSessionView(viewModel: viewModel, group: group)
        }
        .alert("Cancel Session?", isPresented: Binding(
            get: { sessionToCancel != nil },
            set: { if !$0 { sessionToCancel = nil } }
        )) {
            Button("Cancel Session", role: .destructive) {
                if let session = sessionToCancel {
                    Task {
                        await viewModel.cancelSession(sessionId: session.id, groupId: group.id)
                    }
                }
                sessionToCancel = nil
            }
            Button("Keep", role: .cancel) {
                sessionToCancel = nil
            }
        } message: {
            if let session = sessionToCancel {
                Text("Are you sure you want to cancel \"\(session.title)\"? This can't be undone.")
            }
        }
    }

    func nextUpcoming(in sessions: [AppSession]) -> String {
        let upcoming = sessions.filter { $0.status == "upcoming" }.sorted { ($0.proposedAt ?? Date.distantFuture) < ($1.proposedAt ?? Date.distantFuture) }
        if let next = upcoming.first?.proposedAt {
            return next.formatted(date: .abbreviated, time: .omitted)
        }
        return "none"
    }
}

struct SessionRowView: View {
    let session: AppSession
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.title)
                    .font(.headline)
                Spacer()
                StatusBadge(status: session.status)
            }
            if let type = session.sessionType, !type.isEmpty {
                Text(type)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(themeManager.currentTheme.primary.opacity(0.15))
                    .foregroundStyle(themeManager.currentTheme.primary)
                    .clipShape(Capsule())
            }
            if let proposedAt = session.proposedAt {
                Text(proposedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let location = session.location, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? themeManager.currentTheme.primary : Color.white.opacity(0.15))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.8))
                .clipShape(Capsule())
        }
    }
}
