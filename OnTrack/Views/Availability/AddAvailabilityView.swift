import SwiftUI

struct AddAvailabilityView: View {
    @Bindable var viewModel: AvailabilityViewModel
    let session: AppSession
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Your Available Window") {
                    DatePicker("From",
                               selection: $viewModel.newStartsAt,
                               displayedComponents: [.date, .hourAndMinute])
                    DatePicker("To",
                               selection: $viewModel.newEndsAt,
                               displayedComponents: [.date, .hourAndMinute])
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
            .navigationTitle("Add Availability")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        Task {
                            guard let userId = appState.currentUser?.id else { return }
                            await viewModel.addWindow(sessionId: session.id, userId: userId)
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
        }
    }
}
