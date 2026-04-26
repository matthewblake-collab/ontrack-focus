import SwiftUI
import Supabase

struct BreathworkCoachView: View {
    let userId: String
    @Environment(\.dismiss) private var dismiss

    // MARK: - Technique

    struct Technique: Identifiable, Equatable {
        let id: String
        let name: String
        let icon: String
        let inhale: Double
        let hold: Double
        let exhale: Double
        let holdAfter: Double
        let description: String

        var label: String {
            [inhale, hold, exhale, holdAfter]
                .filter { $0 > 0 }
                .map { String(Int($0)) }
                .joined(separator: "-")
        }

        var phases: [(BreathPhase, Double)] {
            [(BreathPhase.inhale, inhale),
             (.hold, hold),
             (.exhale, exhale),
             (.holdAfter, holdAfter)]
                .filter { $0.1 > 0 }
        }
    }

    static let techniques: [Technique] = [
        Technique(id: "box",        name: "Box Breathing",  icon: "square",      inhale: 4, hold: 4, exhale: 4, holdAfter: 4, description: "Equal phases for focus and calm"),
        Technique(id: "478",        name: "4-7-8 Breathing",icon: "wind",        inhale: 4, hold: 7, exhale: 8, holdAfter: 0, description: "Calms the nervous system"),
        Technique(id: "energising", name: "Energising",     icon: "bolt.fill",   inhale: 6, hold: 0, exhale: 2, holdAfter: 0, description: "Boosts energy and alertness"),
        Technique(id: "wimhof",     name: "Wim Hof",        icon: "flame.fill",  inhale: 2, hold: 0, exhale: 1, holdAfter: 0, description: "Rhythmic breathing for vitality")
    ]

    // MARK: - Phase

    enum BreathPhase { case inhale, hold, exhale, holdAfter }

    // MARK: - State

    @State private var selected: Technique = Self.techniques[0]
    @State private var recommended: Technique = Self.techniques[0]
    @State private var recommendationReason: String = ""
    @State private var durationMinutes: Int = 3
    @State private var isRunning = false
    @State private var isComplete = false
    @State private var currentPhase: BreathPhase = .inhale
    @State private var phaseLabel: String = "Ready"
    @State private var phaseDuration: Double = 4
    @State private var circleScale: CGFloat = 0.5
    @State private var timeRemaining: TimeInterval = 0
    @State private var timerTask: Task<Void, Never>?

    private var totalDuration: TimeInterval { Double(durationMinutes) * 60 }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Breathwork")
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

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // Recommendation card
                        if !recommendationReason.isEmpty {
                            recommendationCard
                        }

                        // Technique selector
                        techniqueSelector

                        // Animated breathing circle
                        breathingCircle

                        // Duration picker (idle or complete only)
                        if !isRunning {
                            durationPicker
                        }

                        // Start / stop button
                        controlButton

                        // Time remaining while running
                        if isRunning {
                            Text(timeString(timeRemaining))
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                        }

                        // Complete message
                        if isComplete {
                            Text("Session complete. Great work!")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .task { await loadRecommendation() }
        .onDisappear { timerTask?.cancel() }
    }

    // MARK: - Recommendation Card

    private var recommendationCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(.green)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                Text("Recommended: \(recommended.name)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(recommendationReason)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.green.opacity(0.4), lineWidth: 1))
        )
    }

    // MARK: - Technique Selector

    private var techniqueSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Self.techniques) { technique in
                    Button {
                        guard !isRunning else { return }
                        selected = technique
                        isComplete = false
                        phaseLabel = "Ready"
                        circleScale = 0.5
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: technique.icon)
                                .font(.system(size: 15))
                                .foregroundStyle(selected == technique ? .black : .white)
                            Text(technique.name)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(selected == technique ? .black : .white)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                            Text(technique.label)
                                .font(.system(size: 10))
                                .foregroundStyle(selected == technique ? .black.opacity(0.6) : .white.opacity(0.5))
                        }
                        .frame(width: 82)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selected == technique
                                    ? Color.green
                                    : Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                                    selected == technique ? Color.green : Color.white.opacity(0.12),
                                    lineWidth: 1
                                ))
                        )
                    }
                    .buttonStyle(.plain)
                    .opacity(isRunning ? 0.5 : 1)
                    .disabled(isRunning)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Breathing Circle

    private var breathingCircle: some View {
        ZStack {
            Circle()
                .stroke(Color.green.opacity(0.08), lineWidth: 2)
                .frame(width: 220, height: 220)

            Circle()
                .fill(Color.green.opacity(0.12))
                .frame(width: 200, height: 200)
                .scaleEffect(circleScale)
                .animation(.easeInOut(duration: phaseDuration > 0 ? phaseDuration : 0.4), value: circleScale)

            Circle()
                .stroke(Color.green.opacity(0.5), lineWidth: 2)
                .frame(width: 200, height: 200)
                .scaleEffect(circleScale)
                .animation(.easeInOut(duration: phaseDuration > 0 ? phaseDuration : 0.4), value: circleScale)

            VStack(spacing: 4) {
                Text(phaseLabel)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if isRunning {
                    Text(String(format: "%.0fs", phaseDuration))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .frame(height: 240)
    }

    // MARK: - Duration Picker

    private var durationPicker: some View {
        VStack(spacing: 8) {
            Text("Duration")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.45))
            HStack(spacing: 8) {
                ForEach([1, 3, 5, 10], id: \.self) { mins in
                    Button {
                        durationMinutes = mins
                    } label: {
                        Text("\(mins)m")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(durationMinutes == mins ? .black : .white.opacity(0.7))
                            .frame(width: 52, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(durationMinutes == mins
                                        ? Color.green
                                        : Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(
                                        durationMinutes == mins ? Color.green : Color.white.opacity(0.12),
                                        lineWidth: 1
                                    ))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Control Button

    private var controlButton: some View {
        Button {
            if isRunning {
                stopSession()
            } else {
                startSession()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isRunning ? "stop.fill" : "play.fill")
                Text(isRunning ? "Stop" : "Start Session")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.green))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Session logic

    private func startSession() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isRunning = true
        isComplete = false
        timeRemaining = totalDuration

        timerTask = Task {
            var elapsed: TimeInterval = 0

            outer: while elapsed < totalDuration && !Task.isCancelled {
                for (nextPhase, duration) in selected.phases {
                    guard !Task.isCancelled else { break outer }
                    guard elapsed < totalDuration else { break outer }

                    let clampedDuration = min(duration, totalDuration - elapsed)

                    await MainActor.run {
                        currentPhase = nextPhase
                        phaseDuration = clampedDuration
                        phaseLabel = labelFor(nextPhase)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        switch nextPhase {
                        case .inhale:               circleScale = 1.0
                        case .exhale, .holdAfter:   circleScale = 0.5
                        case .hold:                 break // maintain
                        }
                    }

                    try? await Task.sleep(nanoseconds: UInt64(clampedDuration * 1_000_000_000))
                    elapsed += duration

                    await MainActor.run {
                        timeRemaining = max(0, totalDuration - elapsed)
                    }
                }
            }

            guard !Task.isCancelled else { return }
            await MainActor.run { completeSession() }
        }
    }

    private func stopSession() {
        timerTask?.cancel()
        timerTask = nil
        isRunning = false
        isComplete = false
        phaseLabel = "Ready"
        circleScale = 0.5
        timeRemaining = 0
    }

    private func completeSession() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        isRunning = false
        isComplete = true
        phaseLabel = "Done"
        circleScale = 0.5
        timerTask = nil
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        UserDefaults.standard.set(fmt.string(from: Date()), forKey: "breathwork_completed_date")
    }

    private func labelFor(_ phase: BreathPhase) -> String {
        switch phase {
        case .inhale:    return "Inhale"
        case .hold:      return "Hold"
        case .exhale:    return "Exhale"
        case .holdAfter: return "Hold"
        }
    }

    // MARK: - Recommendation

    private func loadRecommendation() async {
        guard !userId.isEmpty else { setDefault(); return }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())

        struct CheckInScores: Decodable {
            let stress: Int?
            let energy: Int?
        }

        do {
            let rows: [CheckInScores] = try await supabase
                .from("daily_checkins")
                .select("stress, energy")
                .eq("user_id", value: userId)
                .eq("checkin_date", value: today)
                .limit(1)
                .execute()
                .value

            guard let scores = rows.first else { setDefault(); return }

            let stress = scores.stress ?? 5
            let energy = scores.energy ?? 5

            let pick: Technique
            let reason: String

            if stress >= 7 {
                pick = Self.techniques.first { $0.id == "478" }!
                reason = "Your stress is elevated — 4-7-8 can calm your nervous system"
            } else if energy <= 3 {
                pick = Self.techniques.first { $0.id == "energising" }!
                reason = "Your energy is low — try this to feel more alert"
            } else {
                pick = Self.techniques.first { $0.id == "box" }!
                reason = "Balanced day — box breathing to stay focused"
            }

            await MainActor.run {
                recommended = pick
                selected = pick
                recommendationReason = reason
            }
        } catch {
            setDefault()
        }
    }

    private func setDefault() {
        let box = Self.techniques.first { $0.id == "box" }!
        recommended = box
        selected = box
        recommendationReason = "Complete a check-in for a personalised recommendation"
    }

    // MARK: - Helpers

    private func timeString(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}
