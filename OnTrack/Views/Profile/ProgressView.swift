import SwiftUI
import Supabase
import Charts
import HealthKit

// MARK: - Enums

enum ProgressTab: CaseIterable {
    case habits, sessions, supplements, challenges
    var label: String {
        switch self {
        case .habits: return "Habits"
        case .sessions: return "Sessions"
        case .supplements: return "Supplements"
        case .challenges: return "Challenges"
        }
    }
}

private enum PBTopCategory: String, CaseIterable {
    case ergs = "ergs"
    case maxLifts = "max_lifts"
    case bodyweight = "bodyweight"

    var displayName: String {
        switch self {
        case .ergs: return "Ergs"
        case .maxLifts: return "Max Lifts"
        case .bodyweight: return "Bodyweight"
        }
    }
}

private enum ErgMachine: String, CaseIterable {
    case rowErg = "RowErg"
    case skiErg = "SkiErg"
    case bikeErg = "BikeErg"
}

private enum PBInputType: Equatable {
    case metres, time, weight, reps
}

// MARK: - Event lists

private let ergTimeEvents = ["1 Minute", "4 Minutes", "30 Minutes", "60 Minutes"]
private let ergAllEvents: [String] = [
    "1 Minute", "4 Minutes", "30 Minutes", "60 Minutes",
    "100m", "500m", "1000m", "2000m", "5000m", "6000m",
    "10000m", "21097m Half Marathon", "42195m Marathon", "100000m"
]
private let maxLiftEvents: [String] = [
    // Powerlifting
    "Back Squat", "Front Squat", "Bench Press", "Deadlift",
    "Sumo Deadlift", "Overhead Press", "Push Press",
    // Olympic
    "Clean", "Power Clean", "Hang Clean", "Snatch",
    "Power Snatch", "Hang Snatch", "Clean & Jerk", "Jerk",
    // Strength
    "Trap Bar Deadlift", "Romanian Deadlift", "Pause Squat", "Pause Bench Press",
    "Incline Bench Press", "Close Grip Bench Press", "Zercher Squat", "Hip Thrust",
    // Machine
    "Leg Press", "Hack Squat", "Smith Machine Squat", "Smith Machine Bench Press",
    "Chest Press", "Shoulder Press", "Lat Pulldown", "Seated Row"
]
private let bodweightPBEvents: [String] = [
    "Pull-Up", "Chin-Up", "Dip",
    "Weighted Pull-Up", "Weighted Chin-Up", "Weighted Dip",
    "Push-Up"
]

// MARK: - UserProgressView

struct UserProgressView: View {
    let vm: ProgressViewModel
    @State private var selectedTab: ProgressTab = .habits

    private let bg = Color(red: 0.08, green: 0.12, blue: 0.15)
    private let accent = Color(red: 0.2, green: 0.8, blue: 0.4)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Text("My Progress")
                    .font(.largeTitle).fontWeight(.bold).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ProgressTab.allCases, id: \.self) { tab in
                            Button {
                                selectedTab = tab
                            } label: {
                                Text(tab.label)
                                    .font(.subheadline).fontWeight(.medium)
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(Capsule().fill(selectedTab == tab ? accent : Color.white.opacity(0.1)))
                                    .foregroundStyle(selectedTab == tab ? .white : Color.white.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 12) {
                        Group {
                            switch selectedTab {
                            case .habits:      habitsContent
                            case .sessions:    sessionsContent
                            case .supplements: supplementsContent
                            case .challenges:  challengesContent
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 40)
                }
            }
        }
    }

    @ViewBuilder private var habitsContent: some View {
        StatCard(title: "Habits Created",    value: "\(vm.habitsCreated)")
        StatCard(title: "Total Completions", value: "\(vm.habitLogsTotal)")
        StatCard(title: "Completion Rate",   value: "\(Int(vm.habitCompletionPct))%")
        StatCard(title: "Best Streak",       value: "\(vm.habitBestStreak) days")
    }

    @ViewBuilder private var sessionsContent: some View {
        StatCard(title: "Sessions RSVP'd",   value: "\(vm.sessionsRSVPd)")
        StatCard(title: "Sessions Attended", value: "\(vm.sessionsAttended)")
        StatCard(title: "Attendance Rate",   value: "\(Int(vm.sessionAttendancePct))%")
        StatCard(title: "Best Streak",       value: "\(vm.sessionBestStreak) sessions")
    }

    @ViewBuilder private var supplementsContent: some View {
        StatCard(title: "Active Supplements", value: "\(vm.supplementsActive)")
        StatCard(title: "Total Doses Logged", value: "\(vm.supplementLogsTotal)")
        StatCard(title: "Adherence Rate",     value: "\(Int(vm.supplementAdherencePct))%")
        StatCard(title: "Best Streak",        value: "\(vm.supplementBestStreak) days")
    }

    @ViewBuilder private var challengesContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy").font(.system(size: 48)).foregroundStyle(Color.green)
            Text("Challenges coming soon").font(.title3).fontWeight(.medium).foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity).padding(32)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.6), lineWidth: 1.5))
        )
    }
}

// MARK: - TrophyRoomView

struct TrophyRoomView: View {
    let vm: ProgressViewModel
    @State private var showAddPB = false

    private let bg = Color(red: 0.08, green: 0.12, blue: 0.15)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Text("🏆 Trophy Room")
                    .font(.largeTitle).fontWeight(.bold).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 12)

                List {
                    // RUNNING
                    Section {
                        Group {
                            if vm.isLoadingHealth {
                                HStack { Spacer(); SwiftUI.ProgressView().tint(.green); Spacer() }.padding(24)
                            } else if vm.totalKmRun == 0 {
                                StatCard(title: "Total Distance", value: "No HealthKit data — check permissions in Settings")
                            } else {
                                StatCard(title: "Total Distance", value: String(format: "%.1f km", vm.totalKmRun))
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowSeparator(.hidden)
                    } header: {
                        Text("🏃 Running").font(.headline).foregroundStyle(.white).textCase(nil)
                    }

                    // PERSONAL BESTS
                    Section {
                        if vm.isLoadingPBs {
                            HStack { Spacer(); SwiftUI.ProgressView().tint(.green); Spacer() }
                                .listRowBackground(Color.clear).listRowSeparator(.hidden)
                        } else if vm.personalBests.isEmpty {
                            Text("No PBs yet — tap + to add your first")
                                .font(.subheadline).foregroundStyle(Color.white.opacity(0.4))
                                .frame(maxWidth: .infinity).padding(.vertical, 20)
                                .listRowBackground(Color.clear).listRowSeparator(.hidden)
                        } else {
                            ForEach(vm.personalBests) { pb in
                                PBCard(pb: pb)
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            Task {
                                                if let uid = supabase.auth.currentUser?.id {
                                                    await vm.deletePersonalBest(id: pb.id, userId: uid)
                                                }
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    } header: {
                        HStack {
                            Text("🏆 Personal Bests").font(.headline).foregroundStyle(.white).textCase(nil)
                            Spacer()
                            Button { showAddPB = true } label: {
                                Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(Color.green)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        }
        .sheet(isPresented: $showAddPB) {
            AddPBView(vm: vm)
        }
    }
}

// MARK: - PBCard

private struct PBCard: View {
    let pb: PersonalBest

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(pb.eventName).font(.subheadline).fontWeight(.bold).foregroundStyle(.white)
                    Text(pb.category).font(.caption).foregroundStyle(Color.green.opacity(0.8))
                }
                Spacer()
                if pb.isVerified {
                    Text("✓ Verified").font(.caption2).fontWeight(.semibold).foregroundStyle(Color.green)
                } else {
                    Text("Unverified").font(.caption2).foregroundStyle(Color.white.opacity(0.4))
                }
            }
            Text(formattedValue)
                .font(.title2).fontWeight(.bold).foregroundStyle(.white)
            HStack {
                Text(pb.loggedAt).font(.caption).foregroundStyle(.gray)
                Spacer()
                if let urlStr = pb.proofUrl, let url = URL(string: urlStr) {
                    Link("View Proof", destination: url).font(.caption).foregroundStyle(Color.green)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.6), lineWidth: 1.5))
        )
    }

    private var formattedValue: String {
        switch pb.valueUnit {
        case "kg":
            let w = pb.value.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(pb.value))" : String(format: "%.1f", pb.value)
            if let r = pb.reps { return "\(w) kg × \(r) reps" }
            return "\(w) kg"
        case "seconds":
            let mins = Int(pb.value) / 60
            let secs = pb.value.truncatingRemainder(dividingBy: 60)
            return String(format: "%d:%04.1f", mins, secs)
        case "metres":
            let m = pb.value.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(pb.value))" : String(format: "%.1f", pb.value)
            return "\(m) m"
        case "reps":
            return "\(Int(pb.value)) reps"
        default:
            return "\(pb.value) \(pb.valueUnit)"
        }
    }
}

// MARK: - AddPBView

struct AddPBView: View {
    let vm: ProgressViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: PBTopCategory? = nil
    @State private var selectedMachine: String = ""
    @State private var selectedEvent: String = ""
    @State private var valueKg: String = ""
    @State private var additionalReps: String = ""
    @State private var valueMetres: String = ""
    @State private var valueMinutes: String = "0"
    @State private var valueSeconds: String = "0.0"
    @State private var valueReps: String = ""
    @State private var isVerified: Bool = false
    @State private var isPublic: Bool = false
    @State private var loggedAt: Date = Date()
    @State private var proofUrl: String? = nil
    @State private var showImagePicker: Bool = false
    @State private var isUploadingProof: Bool = false
    @State private var isSaving: Bool = false

    private let bg = Color(red: 0.08, green: 0.12, blue: 0.15)

    private var inputType: PBInputType {
        guard let cat = selectedCategory, !selectedEvent.isEmpty else { return .weight }
        switch cat {
        case .ergs:       return ergTimeEvents.contains(selectedEvent) ? .metres : .time
        case .maxLifts:   return .weight
        case .bodyweight: return .reps
        }
    }

    private var eventsForCategory: [String] {
        guard let cat = selectedCategory else { return [] }
        switch cat {
        case .ergs:       return ergAllEvents
        case .maxLifts:   return maxLiftEvents
        case .bodyweight: return bodweightPBEvents
        }
    }

    private var showEventPicker: Bool {
        guard let cat = selectedCategory else { return false }
        return cat == .ergs ? !selectedMachine.isEmpty : true
    }

    private var canSave: Bool {
        guard let cat = selectedCategory, !selectedEvent.isEmpty else { return false }
        if cat == .ergs && selectedMachine.isEmpty { return false }
        switch inputType {
        case .metres:  return (Double(valueMetres) ?? 0) > 0
        case .time:    return (Double(valueMinutes) ?? 0) * 60 + (Double(valueSeconds) ?? 0) > 0
        case .weight:  return (Double(valueKg) ?? 0) > 0
        case .reps:    return (Int(valueReps) ?? 0) > 0
        }
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()
            VStack(spacing: 0) {
                // Nav bar
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.white.opacity(0.6))
                    Spacer()
                    Text("Add Personal Best").font(.headline).fontWeight(.semibold).foregroundStyle(.white)
                    Spacer()
                    if isSaving {
                        SwiftUI.ProgressView().tint(.green)
                    } else {
                        Button("Save") { Task { await save() } }
                            .fontWeight(.semibold)
                            .foregroundStyle(canSave ? Color.green : Color.white.opacity(0.3))
                            .disabled(!canSave)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 16)

                Divider().background(Color.white.opacity(0.1))

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // STEP 1 — Category (3 options)
                        VStack(alignment: .leading, spacing: 10) {
                            fieldLabel("Category")
                            HStack(spacing: 8) {
                                ForEach(PBTopCategory.allCases, id: \.self) { cat in
                                    Button {
                                        selectedCategory = cat
                                        selectedMachine = ""
                                        selectedEvent = ""
                                    } label: {
                                        Text(cat.displayName)
                                            .font(.subheadline).fontWeight(.medium)
                                            .padding(.horizontal, 16).padding(.vertical, 8)
                                            .background(Capsule().fill(
                                                selectedCategory == cat ? Color.green : Color.white.opacity(0.1)
                                            ))
                                            .foregroundStyle(selectedCategory == cat ? .white : Color.white.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // STEP 2a — Erg machine sub-picker
                        if selectedCategory == .ergs {
                            VStack(alignment: .leading, spacing: 10) {
                                fieldLabel("Machine")
                                HStack(spacing: 8) {
                                    ForEach(ErgMachine.allCases, id: \.self) { machine in
                                        Button {
                                            selectedMachine = machine.rawValue
                                            selectedEvent = ""
                                        } label: {
                                            Text(machine.rawValue)
                                                .font(.subheadline).fontWeight(.medium)
                                                .padding(.horizontal, 16).padding(.vertical, 8)
                                                .background(Capsule().fill(
                                                    selectedMachine == machine.rawValue ? Color.green : Color.white.opacity(0.1)
                                                ))
                                                .foregroundStyle(selectedMachine == machine.rawValue ? .white : Color.white.opacity(0.6))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        // STEP 2b — Event picker
                        if showEventPicker {
                            VStack(alignment: .leading, spacing: 10) {
                                fieldLabel("Event")
                                Picker("Event", selection: $selectedEvent) {
                                    Text("Select event").tag("")
                                    ForEach(eventsForCategory, id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.menu)
                                .tint(.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.white.opacity(0.08))
                                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.4), lineWidth: 1))
                                )
                            }
                        }

                        // STEP 3 — Value entry
                        if showEventPicker && !selectedEvent.isEmpty {
                            valueSection
                        }

                        // STEP 4 — Options
                        if showEventPicker && !selectedEvent.isEmpty {
                            optionsSection
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 60)
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView { data in Task { await uploadProof(data: data) } }
        }
    }

    // MARK: - Value entry

    @ViewBuilder
    private var valueSection: some View {
        if inputType == .metres {
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("Metres Achieved")
                TextField("e.g. 342", text: $valueMetres).keyboardType(.decimalPad).darkField()
            }
        } else if inputType == .time {
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("Time (mm:ss.s)")
                HStack(spacing: 8) {
                    TextField("min", text: $valueMinutes).keyboardType(.numberPad).darkField()
                    Text(":").font(.title3).fontWeight(.bold).foregroundStyle(.white)
                    TextField("ss.s", text: $valueSeconds).keyboardType(.decimalPad).darkField()
                }
            }
        } else if inputType == .reps {
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("Reps")
                TextField("e.g. 10", text: $valueReps).keyboardType(.numberPad).darkField()
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("Weight (kg)")
                TextField("e.g. 100", text: $valueKg).keyboardType(.decimalPad).darkField()
                fieldLabel("Reps (optional)")
                TextField("e.g. 3", text: $additionalReps).keyboardType(.numberPad).darkField()
            }
        }
    }

    // MARK: - Extra options

    @ViewBuilder
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: $isVerified) {
                Label("Verified", systemImage: "checkmark.seal.fill").foregroundStyle(.white)
            }
            .tint(.green)

            if isVerified {
                Button { showImagePicker = true } label: {
                    HStack {
                        if isUploadingProof {
                            SwiftUI.ProgressView().tint(.green)
                        } else if proofUrl != nil {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("Proof Added")
                        } else {
                            Image(systemName: "photo.badge.plus").foregroundStyle(.green)
                            Text("Add Proof Photo")
                        }
                    }
                    .foregroundStyle(.white).font(.subheadline).fontWeight(.medium)
                    .frame(maxWidth: .infinity).padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.4), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }

            Toggle(isOn: $isPublic) {
                Label("Make Public", systemImage: "globe").foregroundStyle(.white)
            }
            .tint(.green)

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("Date Achieved")
                DatePicker("", selection: $loggedAt, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(.green)
                    .colorScheme(.dark)
                    .labelsHidden()
            }
        }
    }

    // MARK: - Helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text).font(.caption).fontWeight(.semibold).foregroundStyle(Color.green.opacity(0.8))
    }

    private func uploadProof(data: Data) async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        isUploadingProof = true
        let path = "\(userId.uuidString)/\(UUID().uuidString)_\(Int(Date().timeIntervalSince1970)).jpg"
        do {
            try await supabase.storage
                .from("pb-proofs")
                .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: false))
            let url = try supabase.storage.from("pb-proofs").getPublicURL(path: path)
            proofUrl = url.absoluteString
        } catch {
            print("[AddPB] Proof upload error: \(error)")
        }
        isUploadingProof = false
    }

    private func save() async {
        guard let cat = selectedCategory,
              !selectedEvent.isEmpty,
              let userId = supabase.auth.currentUser?.id else { return }

        // For ergs, append machine to event name
        let eventName: String
        if cat == .ergs {
            guard !selectedMachine.isEmpty else { return }
            eventName = "\(selectedEvent) — \(selectedMachine)"
        } else {
            eventName = selectedEvent
        }

        let pbValue: Double
        let pbUnit: String
        let pbReps: Int?

        switch inputType {
        case .metres:
            guard let m = Double(valueMetres), m > 0 else { return }
            pbValue = m; pbUnit = "metres"; pbReps = nil
        case .time:
            let total = (Double(valueMinutes) ?? 0) * 60 + (Double(valueSeconds) ?? 0)
            guard total > 0 else { return }
            pbValue = total; pbUnit = "seconds"; pbReps = nil
        case .weight:
            guard let kg = Double(valueKg), kg > 0 else { return }
            pbValue = kg; pbUnit = "kg"
            pbReps = additionalReps.isEmpty ? nil : Int(additionalReps)
        case .reps:
            guard let r = Int(valueReps), r > 0 else { return }
            pbValue = Double(r); pbUnit = "reps"; pbReps = nil
        }

        isSaving = true
        await vm.addPersonalBest(
            userId: userId,
            category: cat.rawValue,
            eventName: eventName,
            value: pbValue,
            valueUnit: pbUnit,
            reps: pbReps,
            isVerified: isVerified,
            proofUrl: proofUrl,
            isPublic: isPublic,
            loggedAt: loggedAt
        )
        isSaving = false
        dismiss()
    }
}

// MARK: - StatCard

struct StatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption).fontWeight(.semibold).foregroundStyle(Color.green.opacity(0.8))
            Text(value)
                .font(.title2).fontWeight(.bold).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.6), lineWidth: 1.5))
        )
    }
}

// MARK: - View extension

private extension View {
    func darkField() -> some View {
        self
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.4), lineWidth: 1))
            )
            .foregroundStyle(.white)
    }
}

// MARK: - Personal Progress Sheet

struct PersonalProgressSheet: View {
    var progressVM: ProgressViewModel   // @Observable — no property wrapper needed
    let userId: UUID
    @State private var selectedRange: ProgressRange = .weekly
    @State private var showAddPB = false
    @Environment(\.dismiss) var dismiss

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
    private let goldDark = Color(red: 0.10, green: 0.07, blue: 0.0)
    private let cardBg = Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92)

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.08, blue: 0.10).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {

                        // Gold header banner
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(gold.opacity(0.2))
                                    .frame(width: 52, height: 52)
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.title)
                                    .foregroundStyle(gold)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("My Progress")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                                Text("Track your growth over time")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(cardBg)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(gold.opacity(0.4), lineWidth: 1.5))
                        )
                        .padding(.horizontal)

                        // Range picker
                        Picker("Range", selection: $selectedRange) {
                            Text("Weekly").tag(ProgressRange.weekly)
                            Text("Monthly").tag(ProgressRange.monthly)
                            Text("All Time").tag(ProgressRange.allTime)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .onChange(of: selectedRange) { _, newVal in
                            Task { await progressVM.fetchSessionsAttended(userId: userId, range: newVal) }
                        }

                        // Summary stat grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            progressStatCard(title: "Sessions", value: "\(progressVM.totalSessionsAttended)", icon: "figure.run", color: gold)
                            progressStatCard(title: "Habit Days", value: "\(progressVM.totalHabitDays)", icon: "checkmark.circle", color: .green)
                            progressStatCard(title: "Supplements", value: "\(progressVM.totalSupplementsTaken)", icon: "pills", color: .orange)
                            progressStatCard(title: "Habit Rate", value: "\(Int(progressVM.habitCompletionPct))%", icon: "chart.bar.fill", color: .purple)
                        }
                        .padding(.horizontal)

                        // Apple Health Workouts (pending imports)
                        if !progressVM.pendingHealthWorkouts.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "heart.fill").foregroundStyle(.red)
                                    Text("Apple Health Workouts")
                                        .font(.headline.bold())
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text("\(progressVM.pendingHealthWorkouts.count) new")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                Text("These weren't logged in OnTrack. Save them to your stats?")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.55))

                                ForEach(progressVM.pendingHealthWorkouts, id: \.uuid) { workout in
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(workout.workoutActivityType.displayName)
                                                .font(.subheadline.bold())
                                                .foregroundStyle(.white)
                                            Text("\(Int(workout.duration / 60)) min · \(formatWorkoutDate(workout.startDate))")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.55))
                                        }
                                        Spacer()
                                        Button {
                                            Task {
                                                if let uid = supabase.auth.currentUser?.id {
                                                    await progressVM.saveHealthWorkout(workout, userId: uid)
                                                }
                                            }
                                        } label: {
                                            Text("Save")
                                                .font(.caption).fontWeight(.semibold)
                                                .padding(.horizontal, 12).padding(.vertical, 6)
                                                .background(Capsule().fill(Color.green.opacity(0.85)))
                                                .foregroundStyle(.white)
                                        }
                                        .buttonStyle(.plain)

                                        Button {
                                            progressVM.dismissHealthWorkout(workout)
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.4))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.3), lineWidth: 1))
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }

                        // Bug 2: Imported Apple Health workout aggregate — last 30 days.
                        if progressVM.importedWorkoutCount > 0 {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.18))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "heart.fill")
                                        .foregroundStyle(.red)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Workouts imported")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.white)
                                    Text("Last \(progressVM.importedWorkoutWindowDays) days")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(progressVM.importedWorkoutCount)")
                                        .font(.title2.bold())
                                        .foregroundStyle(.white)
                                    Text("\(progressVM.importedWorkoutMinutes)m · \(progressVM.importedWorkoutCalories) kcal")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.25), lineWidth: 1))
                            )
                            .padding(.horizontal)
                        }

                        // Sessions attended bar chart
                        if !progressVM.sessionStats.isEmpty {
                            progressChartCard(title: "Sessions Attended", accentColor: gold) {
                                Chart(progressVM.sessionStats) { stat in
                                    BarMark(
                                        x: .value("Period", stat.label),
                                        y: .value("Sessions", stat.count)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(colors: [gold, Color(red: 0.95, green: 0.70, blue: 0.10)],
                                                       startPoint: .top, endPoint: .bottom)
                                    )
                                    .cornerRadius(4)
                                }
                                .chartXAxis {
                                    AxisMarks { _ in AxisValueLabel().foregroundStyle(Color.white.opacity(0.6)) }
                                }
                                .chartYAxis {
                                    AxisMarks { _ in
                                        AxisValueLabel().foregroundStyle(Color.white.opacity(0.6))
                                        AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                                    }
                                }
                                .frame(height: 160)
                            }
                        }

                        // TODO: add habitAdherenceHistory to ProgressViewModel to enable this chart
                        // if let adherenceHistory = progressVM.habitAdherenceHistory, !adherenceHistory.isEmpty {
                        //     progressChartCard(title: "Habit Adherence", accentColor: .green) { ... }
                        // }

                        // TODO: add supplementAdherenceHistory to ProgressViewModel to enable this chart
                        // if let supHistory = progressVM.supplementAdherenceHistory, !supHistory.isEmpty {
                        //     progressChartCard(title: "Supplement Adherence", accentColor: .orange) { ... }
                        // }

                        // Personal Bests section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("🏆 Personal Bests")
                                    .font(.headline.bold())
                                    .foregroundStyle(.white)
                                Spacer()
                                Button { showAddPB = true } label: {
                                    Label("Log PB", systemImage: "plus.circle.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.green)
                                }
                            }
                            .padding(.horizontal)

                            // Auto-detected new PBs banner
                            if !progressVM.detectedNewPBs.isEmpty {
                                VStack(spacing: 8) {
                                    HStack {
                                        Image(systemName: "star.fill")
                                            .foregroundStyle(gold)
                                        Text("Possible new PBs detected!")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(gold)
                                        Spacer()
                                    }
                                    ForEach(progressVM.detectedNewPBs, id: \.label) { pb in
                                        HStack {
                                            Text(pb.label)
                                                .font(.subheadline)
                                                .foregroundStyle(.white)
                                            Spacer()
                                            Text(pb.value)
                                                .font(.subheadline.bold())
                                                .foregroundStyle(gold)
                                        }
                                    }
                                    Text("Go to Trophy Room to save these")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(gold.opacity(0.5), lineWidth: 1.5))
                                )
                                .padding(.horizontal)
                            }

                            // Existing PBs list
                            if progressVM.isLoadingPBs {
                                HStack { Spacer(); ProgressView().tint(gold); Spacer() }
                                    .padding()
                            } else if progressVM.personalBests.isEmpty && progressVM.detectedNewPBs.isEmpty {
                                HStack(spacing: 12) {
                                    Image(systemName: "trophy")
                                        .font(.title2)
                                        .foregroundStyle(gold.opacity(0.6))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("No personal bests yet")
                                            .font(.subheadline)
                                            .foregroundStyle(.white)
                                        Text("Tap + to log your first PB")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                    Spacer()
                                }
                                .padding(14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(gold.opacity(0.25), lineWidth: 1))
                                )
                                .padding(.horizontal)
                            } else {
                                ForEach(progressVM.personalBests) { pb in
                                    HStack(spacing: 14) {
                                        ZStack {
                                            Circle()
                                                .fill(gold.opacity(0.15))
                                                .frame(width: 40, height: 40)
                                            Image(systemName: "trophy.fill")
                                                .font(.system(size: 18))
                                                .foregroundStyle(gold)
                                        }
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(pb.eventName)
                                                .font(.subheadline.bold())
                                                .foregroundStyle(.white)
                                            Text(pb.category.replacingOccurrences(of: "_", with: " ").capitalized)
                                                .font(.caption2)
                                                .foregroundStyle(.white.opacity(0.5))
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(String(format: "%.1f", pb.value))
                                                .font(.headline.bold())
                                                .foregroundStyle(gold)
                                            Text(pb.valueUnit)
                                                .font(.caption2)
                                                .foregroundStyle(.white.opacity(0.5))
                                        }
                                        if pb.isVerified {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.caption)
                                                .foregroundStyle(.green)
                                        }
                                    }
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(gold.opacity(0.25), lineWidth: 1))
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationTitle("My Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(gold)
                        .fontWeight(.semibold)
                }
            }
        }
        .task {
            await progressVM.fetchSessionsAttended(userId: userId, range: selectedRange)
            await progressVM.fetchAllTimeTotals(userId: userId)
            await progressVM.detectNewPBs(userId: userId)
            await progressVM.fetchPendingHealthWorkouts(userId: userId)
            await progressVM.fetchHealthWorkoutStats(userId: userId, days: 30)
        }
        .sheet(isPresented: $showAddPB) {
            AddPBView(vm: progressVM)
        }
    }

    @ViewBuilder
    private func progressStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title.bold())
                .foregroundStyle(.white)
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.35), lineWidth: 1))
        )
    }

    @ViewBuilder
    private func progressChartCard<C: View>(title: String, accentColor: Color, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Spacer()
                Circle()
                    .fill(accentColor.opacity(0.25))
                    .frame(width: 8, height: 8)
            }
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(accentColor.opacity(0.2), lineWidth: 1))
        )
        .padding(.horizontal)
    }

    private func formatWorkoutDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }
}
