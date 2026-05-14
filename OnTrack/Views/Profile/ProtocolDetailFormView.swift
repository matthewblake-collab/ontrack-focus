import SwiftUI

struct ProtocolDetailFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager

    let config: ProtocolTypeConfig
    let vm: ProtocolViewModel
    let onSaved: () -> Void

    @State private var protocolName: String = ""
    @State private var goal: String = ""
    @State private var notes: String = ""
    @State private var startDate: Date = Date()
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Calendar.current.date(byAdding: .weekOfYear, value: 12, to: Date()) ?? Date()
    @State private var isSaving: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 10) {
                        Text(config.emoji).font(.largeTitle)
                        VStack(alignment: .leading) {
                            Text(config.displayName).font(.headline)
                            Text("\(config.suggestedDurationWeeks)-week suggested cycle")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text(config.description)
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Name") {
                    TextField("e.g. TRT — First Cycle", text: $protocolName)
                }

                Section("Goal") {
                    TextField("What's the outcome?", text: $goal, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Start") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                }

                Section("End (optional)") {
                    Toggle("Set end date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                    }
                }

                if !config.trackedMarkers.isEmpty {
                    Section("Tracked markers") {
                        Text(config.trackedMarkers.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !config.phases.isEmpty {
                    Section("Phases") {
                        ForEach(config.phases) { phase in
                            HStack {
                                Text(phase.name).font(.subheadline)
                                Spacer()
                                Text("Wk \(phase.weekStart)–\(phase.weekEnd)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Notes (optional)") {
                    TextField("Anything relevant", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(themeManager.backgroundColour())
            .navigationTitle("New Protocol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save").fontWeight(.semibold)
                        }
                    }
                    .disabled(protocolName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
        .onAppear {
            if protocolName.isEmpty {
                protocolName = config.displayName
            }
        }
    }

    private func save() async {
        guard let uid = appState.currentUser?.id else { return }
        isSaving = true
        defer { isSaving = false }
        let ok = await vm.save(
            userId: uid,
            protocolType: config.type,
            protocolName: protocolName.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            goal: goal.isEmpty ? nil : goal,
            notes: notes.isEmpty ? nil : notes
        )
        if ok {
            onSaved()
        }
    }
}
