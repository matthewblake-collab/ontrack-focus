import SwiftUI
import Supabase

struct SupplementDetailView: View {
    let supplement: Supplement
    @ObservedObject var viewModel: SupplementViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var showEditSupplement = false
    @State private var shareProtocolCode: String?
    @State private var isSharingProtocol = false
    @State private var shareProtocolError: String?
    @State private var showShareSheet = false

    var body: some View {
        List {
            Section("Details") {
                HStack {
                    Text("Name")
                    Spacer()
                    Text(supplement.name).foregroundStyle(.secondary)
                }
                if let amount = supplement.doseAmount {
                    HStack {
                        Text("Dose")
                        Spacer()
                        Text("\(String(format: "%g", amount)) \(supplement.doseUnits ?? "")".trimmingCharacters(in: .whitespaces))
                            .foregroundStyle(.secondary)
                    }
                }
                HStack {
                    Text("Timing")
                    Spacer()
                    Label(supplement.timing, systemImage: SupplementTiming(rawValue: supplement.timing)?.icon ?? "clock")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Schedule")
                    Spacer()
                    Text(supplement.daysOfWeek == "everyday" ? "Every day" : "Custom schedule")
                        .foregroundStyle(.secondary)
                }
                if let qty = supplement.stockQuantity {
                    HStack {
                        Text("Stock")
                        Spacer()
                        Text("\(String(format: "%g", qty)) \(supplement.stockUnits ?? "")".trimmingCharacters(in: .whitespaces))
                            .foregroundStyle(.secondary)
                    }
                }
                if let notes = supplement.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes").font(.subheadline)
                        Text(notes).font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let s = supplement.startDate {
                    HStack {
                        Text("Started")
                        Spacer()
                        Text(formattedStartDate(s)).foregroundStyle(.secondary)
                    }
                }
            }
            .listRowBackground(themeManager.cardColour())

            // Bug 1: Share a single supplement's full protocol via the shared_stacks
            // codepath (1-element array, name = "<supp.name> protocol").
            Section {
                Button {
                    Task { await createShareCode() }
                } label: {
                    if isSharingProtocol {
                        ProgressView().tint(.white)
                    } else if let code = shareProtocolCode {
                        Label("Share code: \(code)", systemImage: "square.and.arrow.up")
                    } else {
                        Label("Share Protocol", systemImage: "square.and.arrow.up")
                    }
                }
                .foregroundStyle(themeManager.currentTheme.primary)
                .disabled(isSharingProtocol)
                if let err = shareProtocolError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }
            .listRowBackground(themeManager.cardColour())

            Section {
                Button(role: .destructive) {
                    Task {
                        guard let userId = appState.currentUser?.id else { return }
                        await viewModel.deleteSupplement(id: supplement.id, userId: userId)
                        dismiss()
                    }
                } label: {
                    Label("Remove Supplement", systemImage: "trash")
                }
            }
            .listRowBackground(themeManager.cardColour())
        }
        .themedList(themeManager)
        .navigationTitle(supplement.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if supplement.userId == appState.currentUser?.id {
                    Button("Edit") {
                        showEditSupplement = true
                    }
                    .foregroundStyle(themeManager.currentTheme.primary)
                }
            }
        }
        .sheet(isPresented: $showEditSupplement) {
            EditSupplementView(supplement: supplement, viewModel: viewModel)
                .environmentObject(appState)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showShareSheet) {
            if let code = shareProtocolCode {
                ShareSheetView(items: [
                    "Import my \(supplement.name) protocol in OnTrack.\n\nCode: \(code)"
                ])
            }
        }
    }

    private func createShareCode() async {
        guard let userId = appState.currentUser?.id else { return }
        await MainActor.run {
            isSharingProtocol = true
            shareProtocolError = nil
        }

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

        let code = String((0..<6).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })
        let entry = SupplementEntry(
            name: supplement.name,
            timing: supplement.timing,
            custom_time: supplement.customTime,
            days_of_week: supplement.daysOfWeek,
            dose_amount: supplement.doseAmount,
            dose_units: supplement.doseUnits,
            notes: supplement.notes,
            reminder_enabled: supplement.reminderEnabled,
            in_protocol: supplement.inProtocol
        )
        do {
            try await supabase
                .from("shared_stacks")
                .insert(SharedStackInsert(
                    code: code,
                    created_by: userId.uuidString,
                    name: "\(supplement.name) protocol",
                    supplements: [entry]
                ))
                .execute()
            await MainActor.run {
                shareProtocolCode = code
                isSharingProtocol = false
                showShareSheet = true
            }
        } catch {
            await MainActor.run {
                shareProtocolError = "Could not create share code. Try again."
                isSharingProtocol = false
            }
        }
    }

    private func formattedStartDate(_ dateString: String) -> String {
        let parse = DateFormatter()
        parse.dateFormat = "yyyy-MM-dd"
        let display = DateFormatter()
        display.dateFormat = "d MMM yyyy"
        guard let d = parse.date(from: dateString) else { return dateString }
        return display.string(from: d)
    }
}
