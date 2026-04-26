import SwiftUI
import Supabase

struct ImportStackView: View {
    @ObservedObject var viewModel: SupplementViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var code: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var fetchedStack: SharedStack? = nil
    @State private var selectedIds: Set<Int> = []
    @State private var isImporting = false
    @State private var importSuccess = false

    struct SharedStack {
        let code: String
        let name: String
        let supplements: [[String: Any]]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if importSuccess {
                        importSuccessCard
                    } else if let stack = fetchedStack {
                        previewCard(stack: stack)
                    } else {
                        enterCodeCard
                        if let error = errorMessage {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                                .padding(.horizontal)
                        }
                        lookupButton
                    }
                }
                .padding(.vertical)
            }
            .background(themeManager.backgroundColour())
            .navigationTitle("Import Stack")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sub views

    private var enterCodeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 6) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 32))
                    .foregroundColor(themeManager.currentTheme.primary)
                Text("Import a Stack")
                    .font(.title2.bold())
                Text("Enter the 6-character code shared with you")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                Text("Share Code")
                    .font(.headline)
                    .padding(.horizontal)
                TextField("e.g. ABC123", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(themeManager.currentTheme.primary.opacity(0.4), lineWidth: 1))
                    .padding(.horizontal)
                    .onChange(of: code) { _, newValue in
                        code = String(newValue.prefix(6)).uppercased()
                    }
            }
        }
    }

    private var lookupButton: some View {
        Button {
            Task { await lookupStack() }
        } label: {
            if isLoading {
                ProgressView().tint(.white).frame(maxWidth: .infinity).padding()
            } else {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Find Stack").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundStyle(.white)
            }
        }
        .background(code.count == 6 ? AnyShapeStyle(themeManager.currentTheme.gradient) : AnyShapeStyle(Color.gray.opacity(0.3)))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .disabled(code.count != 6 || isLoading)
        .padding(.horizontal)
    }

    private func previewCard(stack: SharedStack) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "pills.fill")
                    .font(.system(size: 32))
                    .foregroundColor(themeManager.currentTheme.primary)
                Text(stack.name)
                    .font(.title2.bold())
                Text("\(stack.supplements.count) supplement\(stack.supplements.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Choose what to import")
                        .font(.headline)
                    Spacer()
                    Button(selectedIds.count == stack.supplements.count ? "Deselect All" : "Select All") {
                        if selectedIds.count == stack.supplements.count {
                            selectedIds = []
                        } else {
                            selectedIds = Set(0..<stack.supplements.count)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.primary)
                }
                .padding(.horizontal)

                VStack(spacing: 0) {
                    ForEach(Array(stack.supplements.enumerated()), id: \.offset) { index, supp in
                        Button {
                            if selectedIds.contains(index) {
                                selectedIds.remove(index)
                            } else {
                                selectedIds.insert(index)
                            }
                        } label: {
                            HStack(spacing: 14) {
                                let timing = supp["timing"] as? String ?? "morning"
                                ZStack {
                                    Circle()
                                        .fill(themeManager.currentTheme.gradient)
                                        .frame(width: 36, height: 36)
                                    Image(systemName: SupplementTiming(rawValue: timing)?.icon ?? "pills.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(supp["name"] as? String ?? "")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)
                                    if let dose = supp["dose"] as? String, !dose.isEmpty {
                                        Text(dose)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(timing.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: selectedIds.contains(index) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedIds.contains(index) ? themeManager.currentTheme.primary : .secondary)
                                    .font(.system(size: 20))
                            }
                            .padding()
                        }
                        .buttonStyle(.plain)
                        if index < stack.supplements.count - 1 {
                            Divider().padding(.leading, 64)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Text("\(selectedIds.count) of \(stack.supplements.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            Button {
                Task { await importStack(stack: stack) }
            } label: {
                if isImporting {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding()
                } else {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import \(selectedIds.count) Supplement\(selectedIds.count == 1 ? "" : "s")")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundStyle(.white)
                }
            }
            .background(selectedIds.isEmpty ? AnyShapeStyle(Color.gray.opacity(0.3)) : AnyShapeStyle(themeManager.currentTheme.gradient))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .disabled(selectedIds.isEmpty || isImporting)
            .padding(.horizontal)
        }
    }

    private var importSuccessCard: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.green)
                Text("Stack Imported!")
                    .font(.title2.bold())
                Text("The supplements have been added to your stack")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Button("Done") { dismiss() }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundStyle(.white)
                .background(themeManager.currentTheme.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
        }
    }

    // MARK: - Logic

    func lookupStack() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await supabase
                .from("shared_stacks")
                .select()
                .eq("code", value: code.uppercased())
                .single()
                .execute()

            let json = try JSONSerialization.jsonObject(with: response.data) as? [String: Any]
            let name = json?["name"] as? String ?? "Shared Stack"
            let supplements = json?["supplements"] as? [[String: Any]] ?? []

            await MainActor.run {
                fetchedStack = SharedStack(code: code, name: name, supplements: supplements)
                selectedIds = Set(0..<supplements.count)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Stack not found. Check the code and try again."
            }
        }
        await MainActor.run { isLoading = false }
    }

    func importStack(stack: SharedStack) async {
        guard let userId = appState.currentUser?.id else { return }
        isImporting = true

        let toImport = selectedIds.sorted().map { stack.supplements[$0] }

        do {
            // Bug 1: decode the expanded 9-field payload. Old payloads (6 fields) still
            // decode fine — all new fields are optional so legacy codes keep working.
            struct SupplementImport: Encodable {
                let user_id: String
                let name: String
                let timing: String
                let custom_time: String?
                let days_of_week: String
                let is_active: Bool
                let dose_amount: Double?
                let dose_units: String?
                let notes: String?
                let reminder_enabled: Bool
                let in_protocol: Bool
            }

            for supp in toImport {
                let entry = SupplementImport(
                    user_id: userId.uuidString,
                    name: supp["name"] as? String ?? "",
                    timing: supp["timing"] as? String ?? "morning",
                    custom_time: supp["custom_time"] as? String,
                    days_of_week: supp["days_of_week"] as? String ?? "everyday",
                    is_active: true,
                    dose_amount: supp["dose_amount"] as? Double,
                    dose_units: supp["dose_units"] as? String,
                    notes: supp["notes"] as? String,
                    reminder_enabled: supp["reminder_enabled"] as? Bool ?? false,
                    in_protocol: supp["in_protocol"] as? Bool ?? false
                )
                try await supabase
                    .from("supplements")
                    .insert(entry)
                    .execute()
            }

            if let uid = appState.currentUser?.id {
                await viewModel.fetchSupplements(userId: uid)
            }
            await MainActor.run { importSuccess = true }
        } catch {
            await MainActor.run { errorMessage = "Import failed. Please try again." }
        }
        await MainActor.run { isImporting = false }
    }
}
