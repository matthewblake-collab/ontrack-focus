import SwiftUI

struct CreateGroupView: View {
    @Bindable var viewModel: GroupViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Group Details") {
                    TextField("Group Name", text: $viewModel.newGroupName)
                    TextField("Description (optional)", text: $viewModel.newGroupDescription)
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
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        Task {
                            guard let userId = appState.currentUser?.id else { return }
                            await viewModel.createGroup(userId: userId)
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.newGroupName.isEmpty || viewModel.isLoading)
                }
            }
        }
    }
}
