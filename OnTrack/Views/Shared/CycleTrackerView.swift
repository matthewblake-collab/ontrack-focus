import SwiftUI

struct CycleTrackerView: View {
    let userId: String
    @Environment(\.dismiss) private var dismiss
    @State private var vm = CycleTrackerViewModel()

    // Log form state
    @State private var showLogForm = false
    @State private var logStart = Date()
    @State private var logHasEnd = false
    @State private var logEnd = Date()
    @State private var selectedSymptoms: Set<String> = []
    @State private var logNotes = ""

    private let allSymptoms = [
        "Cramps", "Fatigue", "Bloating", "Headache",
        "Mood swings", "Breast tenderness", "Back pain", "Insomnia"
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Cycle Tracker")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)

                if vm.isLoading {
                    Spacer()
                    ProgressView().tint(.green)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            phaseCard
                            logPeriodSection
                            if !vm.logs.isEmpty {
                                phaseInsightsCard
                                historySection
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .task { await vm.fetch(userId: userId) }
    }

    // MARK: - Phase Card

    private var phaseCard: some View {
        VStack(spacing: 12) {
            if vm.logs.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "circle.dashed")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.5))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No data yet")
                            .font(.headline.bold())
                            .foregroundStyle(.white)
                        Text("Log your first period to track your cycle")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                }
            } else {
                let phase = vm.currentPhase
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(phaseColor(phase).opacity(0.2))
                            .frame(width: 56, height: 56)
                        Image(systemName: phase.icon)
                            .font(.system(size: 22))
                            .foregroundStyle(phaseColor(phase))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(phase.name)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        if let day = vm.dayOfCycle {
                            Text("Day \(day) of cycle")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        if let daysLeft = vm.daysUntilNext {
                            Text(daysLeft == 0 ? "Period expected today" : "\(daysLeft) days until next period")
                                .font(.caption)
                                .foregroundStyle(daysLeft <= 2 ? .orange : .white.opacity(0.5))
                        } else if phase == .overdue {
                            Text("Period may be late")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.3), lineWidth: 1))
        )
    }

    // MARK: - Log Period Section

    private var logPeriodSection: some View {
        VStack(spacing: 0) {
            // Toggle button
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showLogForm.toggle()
                    if !showLogForm {
                        resetLogForm()
                    }
                }
            } label: {
                HStack {
                    Image(systemName: showLogForm ? "chevron.up" : "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)
                    Text(showLogForm ? "Cancel" : "Log Period")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: showLogForm ? 16 : 16)
                        .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(
                            showLogForm ? Color.green.opacity(0.4) : Color.white.opacity(0.12), lineWidth: 1
                        ))
                )
            }
            .buttonStyle(.plain)

            if showLogForm {
                logForm
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var logForm: some View {
        VStack(spacing: 14) {
            // Period start
            VStack(alignment: .leading, spacing: 6) {
                Text("Period started")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                DatePicker("", selection: $logStart, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(.green)
                    .colorScheme(.dark)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Period end toggle
            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $logHasEnd) {
                    Text("Period ended")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .tint(.green)
                if logHasEnd {
                    DatePicker("", selection: $logEnd, in: logStart...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(.green)
                        .colorScheme(.dark)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Symptoms
            VStack(alignment: .leading, spacing: 8) {
                Text("Symptoms")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(allSymptoms, id: \.self) { symptom in
                        let selected = selectedSymptoms.contains(symptom)
                        Button {
                            if selected {
                                selectedSymptoms.remove(symptom)
                            } else {
                                selectedSymptoms.insert(symptom)
                            }
                        } label: {
                            Text(symptom)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(selected ? .black : .white.opacity(0.8))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selected ? Color.green : Color.white.opacity(0.08))
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                                            selected ? Color.green : Color.white.opacity(0.15), lineWidth: 1
                                        ))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Notes
            VStack(alignment: .leading, spacing: 6) {
                Text("Notes (optional)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                TextField("How are you feeling?", text: $logNotes, axis: .vertical)
                    .lineLimit(3...5)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    )
                    .foregroundStyle(.white)
                    .tint(.green)
            }

            // Submit
            Button {
                Task {
                    await vm.logPeriod(
                        userId: userId,
                        start: logStart,
                        end: logHasEnd ? logEnd : nil,
                        symptoms: Array(selectedSymptoms),
                        notes: logNotes
                    )
                    withAnimation { showLogForm = false }
                    resetLogForm()
                }
            } label: {
                Group {
                    if vm.isSubmitting {
                        ProgressView().tint(.black)
                    } else {
                        Text("Save Period Log")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.green))
            }
            .buttonStyle(.plain)
            .disabled(vm.isSubmitting)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.3), lineWidth: 1))
        )
    }

    // MARK: - Phase Insights

    private var phaseInsightsCard: some View {
        let phase = vm.currentPhase
        let checkIn = vm.todayCheckIn

        return VStack(alignment: .leading, spacing: 12) {
            Text("Phase Insights")
                .font(.subheadline.bold())
                .foregroundStyle(.white)

            insightRow(icon: "figure.run", label: "Training", advice: phase.trainingAdvice)
            Divider().background(Color.white.opacity(0.1))
            insightRow(icon: "pills.fill", label: "Supplements", advice: phase.supplementAdvice)
            Divider().background(Color.white.opacity(0.1))

            // Mood row with check-in overlay
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14))
                        .foregroundStyle(.green)
                        .frame(width: 20)
                    Text("Mood")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.6))
                }
                Text(phase.moodAdvice)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.leading, 28)
                if let c = checkIn {
                    HStack(spacing: 12) {
                        if let stress = c.stress {
                            checkInBadge(label: "Stress", value: stress, warnAbove: 6)
                        }
                        if let energy = c.energy {
                            checkInBadge(label: "Energy", value: energy, warnBelow: 4)
                        }
                        if let mood = c.mood {
                            checkInBadge(label: "Mood", value: mood, warnBelow: 4)
                        }
                    }
                    .padding(.leading, 28)
                    .padding(.top, 2)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12), lineWidth: 1))
        )
    }

    private func insightRow(icon: String, label: String, advice: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.green)
                    .frame(width: 20)
                Text(label)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.6))
            }
            Text(advice)
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.leading, 28)
        }
    }

    private func checkInBadge(label: String, value: Int, warnAbove: Int? = nil, warnBelow: Int? = nil) -> some View {
        let isWarning = (warnAbove.map { value > $0 } ?? false) || (warnBelow.map { value < $0 } ?? false)
        return VStack(spacing: 2) {
            Text("\(value)/10")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(isWarning ? .orange : .white)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isWarning ? Color.orange.opacity(0.15) : Color.white.opacity(0.06))
        )
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("History")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 2)

            ForEach(vm.logs) { log in
                historyRow(log: log)
            }
        }
    }

    private func historyRow(log: CycleLog) -> some View {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"

        let startStr = fmt.string(from: log.periodStartDate)
        let rangeStr: String
        let durationStr: String

        if let end = log.periodEndDate {
            let days = Calendar.current.dateComponents([.day], from: log.periodStartDate, to: end).day ?? 0
            rangeStr = "\(startStr) → \(fmt.string(from: end))"
            durationStr = "\(days + 1) days"
        } else {
            rangeStr = "\(startStr) → ongoing"
            durationStr = ""
        }

        return HStack(spacing: 10) {
            Image(systemName: "drop.fill")
                .font(.system(size: 12))
                .foregroundStyle(.red.opacity(0.7))
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(rangeStr)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                if let len = log.cycleLength {
                    Text("Cycle: \(len) days\(durationStr.isEmpty ? "" : " · Period: \(durationStr)")")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                } else if !durationStr.isEmpty {
                    Text("Period: \(durationStr)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
                if let symptoms = log.symptoms, !symptoms.isEmpty {
                    Text(symptoms.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }

    // MARK: - Helpers

    private func phaseColor(_ phase: CyclePhase) -> Color {
        switch phase {
        case .menstrual:  return Color(red: 0.9, green: 0.3, blue: 0.3)
        case .follicular: return Color.green
        case .ovulation:  return Color(red: 1.0, green: 0.85, blue: 0.0)
        case .luteal:     return Color(red: 0.6, green: 0.4, blue: 0.9)
        default:          return Color.white.opacity(0.5)
        }
    }

    private func resetLogForm() {
        logStart = Date()
        logHasEnd = false
        logEnd = Date()
        selectedSymptoms = []
        logNotes = ""
    }
}
