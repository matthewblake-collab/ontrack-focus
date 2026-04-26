import SwiftUI

struct AvailabilityView: View {
    let session: AppSession
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var viewModel = AvailabilityViewModel()
    @State private var showAddWindow = false

    var body: some View {
        List {
            Section("My Availability") {
                if viewModel.myWindows.isEmpty {
                    Text("You haven't added any availability yet")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(viewModel.myWindows) { window in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(window.startsAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                            Text("to \(window.endsAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                Task {
                                    guard let userId = appState.currentUser?.id else { return }
                                    await viewModel.deleteWindow(windowId: window.id, sessionId: session.id, userId: userId)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }

                Button {
                    showAddWindow = true
                } label: {
                    Label("Add Availability", systemImage: "plus.circle")
                }
            }
            .listRowBackground(themeManager.cardColour())

            Section("Group Availability (\(Set(viewModel.windows.map { $0.userId }).count) members)") {
                if viewModel.windows.isEmpty {
                    Text("No one has added availability yet")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(viewModel.windows) { window in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(window.startsAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                            Text("to \(window.endsAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
        .navigationTitle("Availability")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddWindow = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            guard let userId = appState.currentUser?.id else { return }
            await viewModel.fetchWindows(sessionId: session.id, userId: userId)
        }
        .sheet(isPresented: $showAddWindow) {
            AddAvailabilityView(viewModel: viewModel, session: session)
        }
    }
}
