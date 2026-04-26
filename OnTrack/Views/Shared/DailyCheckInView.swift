import SwiftUI
import Supabase
import HealthKit
import UserNotifications

// MARK: - ViewModel

@Observable
final class DailyCheckInViewModel {
    var sleep = 0
    var energy = 0
    var wellbeing = 0
    var mood: Int = 5
    var stress: Int = 5
    var isSubmitting = false
    var errorMessage: String? = nil
    var healthKitPrefilled = false

    var canSubmit: Bool {
        sleep > 0 && energy > 0 && wellbeing > 0 && !isSubmitting
    }

    func prefillFromHealthKit() {
        guard !healthKitPrefilled else { return }
        let hk = HealthKitManager.shared
        guard hk.isAuthorized else { return }

        var didPrefill = false

        if let score = hk.sleepScore(), sleep == 0 {
            sleep = score
            didPrefill = true
        }

        if energy == 0, let steps = hk.stepCount {
            let score: Int
            switch steps {
            case ..<2_000:  score = 1
            case ..<5_000:  score = 2
            case ..<8_000:  score = 3
            case ..<12_000: score = 4
            default:        score = 5
            }
            energy = score
            didPrefill = true
        }

        healthKitPrefilled = didPrefill
    }

    func reset() {
        sleep = 0
        energy = 0
        wellbeing = 0
        mood = 5
        stress = 5
        healthKitPrefilled = false
        errorMessage = nil
    }

    func submit(userId: UUID) async -> Bool {
        isSubmitting = true
        errorMessage = nil

        struct CheckInInsert: Encodable {
            let userId: UUID
            let checkinDate: String
            let sleep: Int
            let energy: Int
            let wellbeing: Int
            let mood: Int
            let stress: Int
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case checkinDate = "checkin_date"
                case sleep
                case energy
                case wellbeing
                case mood
                case stress
            }
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())

        do {
            try await supabase
                .from("daily_checkins")
                .upsert(CheckInInsert(
                    userId: userId,
                    checkinDate: today,
                    sleep: sleep,
                    energy: energy,
                    wellbeing: wellbeing,
                    mood: mood,
                    stress: stress
                ), onConflict: "user_id,checkin_date")
                .execute()
            UserDefaults.standard.set(today, forKey: "checkin_completed_date")
            AnalyticsManager.shared.track(.checkinSubmitted)
            isSubmitting = false
            return true
        } catch {
            print("❌ Check-in save error: \(error)")
            errorMessage = error.localizedDescription
            isSubmitting = false
            return false
        }
    }
}

// MARK: - View

struct DailyCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager
    @Bindable var vm: DailyCheckInViewModel

    private let gradientStart = Color(red: 0.08, green: 0.35, blue: 0.45)
    private let gradientEnd   = Color(red: 0.15, green: 0.55, blue: 0.38)

    var body: some View {
        ZStack {
            // Background
            GeometryReader { geo in
                Image(themeManager.currentBackgroundImage)
                    .resizable()
                    .scaledToFill()
                    .grayscale(1.0)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()

                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.70),
                        Color.black.opacity(0.45)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }

            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 6) {
                        Text("Daily Check-in")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text(todayLabel())
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.65))
                        if vm.healthKitPrefilled {
                            Label("Pre-filled from Health", systemImage: "heart.fill")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.55))
                                .padding(.top, 2)
                        }
                    }
                    .padding(.top, 48)

                    // Rating rows
                    VStack(spacing: 16) {
                        CheckInRatingRow(
                            label: "Sleep",
                            icon: "moon.fill",
                            rating: $vm.sleep,
                            gradientStart: gradientStart,
                            gradientEnd: gradientEnd
                        )
                        CheckInRatingRow(
                            label: "Energy",
                            icon: "bolt.fill",
                            rating: $vm.energy,
                            gradientStart: gradientStart,
                            gradientEnd: gradientEnd
                        )
                        CheckInRatingRow(
                            label: "Wellbeing",
                            icon: "heart.fill",
                            rating: $vm.wellbeing,
                            gradientStart: gradientStart,
                            gradientEnd: gradientEnd
                        )
                        CheckInRatingRow(
                            label: "Mood",
                            icon: "face.smiling.fill",
                            rating: $vm.mood,
                            gradientStart: gradientStart,
                            gradientEnd: gradientEnd
                        )
                        CheckInRatingRow(
                            label: "Stress",
                            icon: "exclamationmark.triangle.fill",
                            rating: $vm.stress,
                            gradientStart: Color(red: 0.55, green: 0.15, blue: 0.10),
                            gradientEnd: Color(red: 0.75, green: 0.30, blue: 0.10),
                            subtitle: "Lower is better"
                        )
                    }
                    .padding(.horizontal)

                    // Error
                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.9))
                            .padding(.horizontal)
                    }

                    // Submit
                    Button {
                        guard let userId = appState.currentUser?.id else {
                            print("❌ Check-in submit failed: currentUser is nil")
                            return
                        }
                        print("✅ Check-in submitting for userId: \(userId)")
                        Task {
                            let success = await vm.submit(userId: userId)
                            if success {
                                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-checkin-reminder"])
                                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["daily-checkin-reminder"])
                            }
                            if success { dismiss() }
                        }
                    } label: {
                        ZStack {
                            if vm.isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Text("Submit")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [gradientStart, gradientEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .opacity(vm.canSubmit ? 1 : 0.45)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!vm.canSubmit)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            vm.prefillFromHealthKit()
        }
    }

    private func todayLabel() -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMM yyyy"
        return f.string(from: Date())
    }
}

// MARK: - Rating Row

private struct CheckInRatingRow: View {
    let label: String
    let icon: String
    @Binding var rating: Int
    let gradientStart: Color
    let gradientEnd: Color
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                Text(label)
                    .font(.headline)
                    .foregroundColor(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            HStack(spacing: 4) {
                ForEach(1...10, id: \.self) { star in
                    Button {
                        rating = star
                    } label: {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .foregroundStyle(
                                star <= rating
                                    ? AnyShapeStyle(LinearGradient(
                                        colors: [gradientStart, gradientEnd],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                      ))
                                    : AnyShapeStyle(Color.white.opacity(0.35))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
