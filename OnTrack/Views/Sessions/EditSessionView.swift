import SwiftUI

struct EditSessionView: View {
    let session: AppSession
    let group: AppGroup
    @State private var viewModel = SessionViewModel()
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

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

                    SectionCard(title: "Visibility") {
                        Toggle(isOn: Binding(
                            get: { viewModel.newVisibility == "friends" },
                            set: { viewModel.newVisibility = $0 ? "friends" : "private" }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Visible to friends")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                Text("Friends can see and join this session")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        .tint(Color(red: 0.15, green: 0.55, blue: 0.38))
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }

                    Button {
                        Task {
                            await viewModel.updateSession(session: session)
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Save Changes")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(themeManager.currentTheme.primary)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .disabled(viewModel.newTitle.isEmpty || viewModel.isLoading)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(themeManager.backgroundColour())
            .onAppear {
                viewModel.newTitle = session.title
                viewModel.newDescription = session.description ?? ""
                viewModel.newLocation = session.location ?? ""
                viewModel.newSessionType = session.sessionType ?? ""
                viewModel.newProposedAt = session.proposedAt ?? Date()
                viewModel.newVisibility = session.visibility ?? "private"
            }
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
