import SwiftUI

struct JoinGroupView: View {
    @Bindable var viewModel: GroupViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Enter Invite Code") {
                    TextField("Invite Code", text: $viewModel.inviteCodeInput)
                        .textInputAutocapitalization(.characters)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(themeManager.backgroundColour())
            .navigationTitle("Join Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Join") {
                        Task {
                            guard let userId = appState.currentUser?.id else { return }
                            await viewModel.joinGroup(userId: userId)
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.inviteCodeInput.isEmpty || viewModel.isLoading)
                }
            }
        }
    }
}
