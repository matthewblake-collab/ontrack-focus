import SwiftUI
import Supabase

struct ShareStackView: View {
    @ObservedObject var viewModel: SupplementViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedIds: Set<UUID> = []
    @State private var stackName: String = ""
    @State private var isSharing = false
    @State private var shareCode: String? = nil
    @State private var errorMessage: String? = nil
    @State private var showShareSheet = false
    @State private var selectAll = true

    var selectedSupplements: [Supplement] {
        viewModel.supplements.filter { selectedIds.contains($0.id) }
    }

    var shareURL: String {
        "ontrack://stack/\(shareCode ?? "")"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let code = shareCode {
                        successCard(code: code)
                    } else {
                        nameCard
                        selectCard
                        if let error = errorMessage {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                                .padding(.horizontal)
                        }
                        shareButton
                    }
                }
                .padding(.vertical)
            }
            .background(themeManager.backgroundColour())
            .navigationTitle("Share Stack")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                selectedIds = Set(viewModel.supplements.map { $0.id })
                stackName = "\(appState.currentUser?.displayName ?? "My") Stack"
            }
            .sheet(isPresented: $showShareSheet) {
                if let code = shareCode {
                    ShareSheetView(items: [
                        "Check out my supplement stack on OnTrack! Import it using this link: ontrack://stack/\(code)"
                    ])
                }
            }
        }
    }

    // MARK: - Sub views

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stack Name")
                .font(.headline)
                .padding(.horizontal)
            VStack {
                OnTrackTextField(placeholder: "e.g. My Supplement Stack", text: $stackName)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    private var selectCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Select Supplements")
                    .font(.headline)
                Spacer()
                Button(selectAll ? "Deselect All" : "Select All") {
                    selectAll.toggle()
                    if selectAll {
                        selectedIds = Set(viewModel.supplements.map { $0.id })
                    } else {
                        selectedIds = []
                    }
                }
                .font(.subheadline)
                .foregroundColor(themeManager.currentTheme.primary)
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(viewModel.supplements) { supplement in
                    Button {
                        if selectedIds.contains(supplement.id) {
                            selectedIds.remove(supplement.id)
                        } else {
                            selectedIds.insert(supplement.id)
                        }
                        selectAll = selectedIds.count == viewModel.supplements.count
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(themeManager.currentTheme.gradient)
                                    .frame(width: 36, height: 36)
                                Image(systemName: SupplementTiming(rawValue: supplement.timing)?.icon ?? "pills.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(supplement.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                if let amount = supplement.doseAmount {
                                    Text("\(String(format: "%g", amount)) \(supplement.doseUnits ?? "")".trimmingCharacters(in: .whitespaces))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: selectedIds.contains(supplement.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedIds.contains(supplement.id) ? themeManager.currentTheme.primary : .secondary)
                                .font(.system(size: 20))
                        }
                        .padding()
                    }
                    .buttonStyle(.plain)
                    if supplement.id != viewModel.supplements.last?.id {
                        Divider().padding(.leading, 64)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            Text("\(selectedIds.count) of \(viewModel.supplements.count) supplements selected")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }

    private var shareButton: some View {
        Button {
            Task { await createSharedStack() }
        } label: {
            if isSharing {
                ProgressView().tint(.white).frame(maxWidth: .infinity).padding()
            } else {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Create Share Link")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundStyle(.white)
            }
        }
        .background(selectedIds.isEmpty || stackName.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(themeManager.currentTheme.gradient))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(selectedIds.isEmpty || stackName.isEmpty || isSharing)
        .padding(.horizontal)
    }

    private func successCard(code: String) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.green)
                Text("Stack Ready to Share!")
                    .font(.title2.bold())
                Text("Anyone with this link can import your stack into OnTrack")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            VStack(spacing: 12) {
                Text("Share Code")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(code)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(themeManager.currentTheme.primary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(themeManager.currentTheme.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            VStack(spacing: 12) {
                Button {
                    showShareSheet = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Link").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundStyle(.white)
                    .background(themeManager.currentTheme.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    UIPasteboard.general.string = "ontrack://stack/\(code)"
                } label: {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy Link").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundStyle(themeManager.currentTheme.primary)
                    .background(themeManager.currentTheme.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button("Done") { dismiss() }
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Logic

    func createSharedStack() async {
        guard let userId = appState.currentUser?.id else { return }
        isSharing = true
        errorMessage = nil

        let code = String((0..<6).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })

        // Bug 1: expanded from 6 → 9 fields so recipients actually get the full
        // protocol (timing, schedule, dose + units, notes, reminder toggle, in_protocol).
        struct SupplementEntry: Encodable {
            let name: String
            let timing: String
            let custom_time: String?
            let days_of_week: String
            let dose_amount: Double?
            let dose_units: String?
            let notes: String?
            let reminder_enabled: Bool?
            let in_protocol: Bool?
        }

        struct SharedStackInsert: Encodable {
            let code: String
            let created_by: String
            let name: String
            let supplements: [SupplementEntry]
        }

        let supplementsData = selectedSupplements.map { s in
            SupplementEntry(
                name: s.name,
                timing: s.timing,
                custom_time: s.customTime,
                days_of_week: s.daysOfWeek,
                dose_amount: s.doseAmount,
                dose_units: s.doseUnits,
                notes: s.notes,
                reminder_enabled: s.reminderEnabled,
                in_protocol: s.inProtocol
            )
        }

        do {
            try await supabase
                .from("shared_stacks")
                .insert(SharedStackInsert(
                    code: code,
                    created_by: userId.uuidString,
                    name: stackName,
                    supplements: supplementsData
                ))
                .execute()
            await MainActor.run { shareCode = code }
        } catch {
            await MainActor.run { errorMessage = "Failed to create share link. Please try again." }
        }
        await MainActor.run { isSharing = false }
    }
}

struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
