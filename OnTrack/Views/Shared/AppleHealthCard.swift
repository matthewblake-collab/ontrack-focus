import SwiftUI
import HealthKit

struct AppleHealthCard: View {
    @State private var hk = HealthKitManager.shared
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showWorkouts = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                Text("Apple Health")
                    .font(.headline)
                Spacer()
                if hk.isAuthorized {
                    Button(action: { Task { await hk.fetchAll() } }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !hk.isAuthorized {
                VStack(spacing: 10) {
                    Text("Connect Apple Health to see your stats here and pre-fill your daily check-in.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: { Task { await hk.requestAuthorization() } }) {
                        Label("Connect Health", systemImage: "heart.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .cornerRadius(20)
                    }
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    if let v = hk.sleepHours {
                        HealthStatTile(icon: "moon.fill", color: .indigo, label: "Sleep", value: String(format: "%.1fh", v))
                    }
                    if let v = hk.restingHeartRate {
                        HealthStatTile(icon: "heart.fill", color: .red, label: "Resting HR", value: String(format: "%.0f bpm", v))
                    }
                    if let v = hk.stepCount {
                        HealthStatTile(icon: "figure.walk", color: .green, label: "Steps", value: String(format: "%.0f", v))
                    }
                    if let v = hk.activeEnergy {
                        HealthStatTile(icon: "flame.fill", color: .orange, label: "Active Cal", value: String(format: "%.0f kcal", v))
                    }
                    if let v = hk.walkRunDistance {
                        HealthStatTile(icon: "figure.run", color: .teal, label: "Distance", value: String(format: "%.1f km", v))
                    }
                    if hk.cyclingDistanceKm > 0 {
                        HealthStatTile(icon: "figure.outdoor.cycle", color: .green, label: "Cycling", value: String(format: "%.1f km", hk.cyclingDistanceKm))
                    }
                    if let v = hk.exerciseMinutes {
                        HealthStatTile(icon: "stopwatch.fill", color: .yellow, label: "Exercise", value: String(format: "%.0f min", v))
                    }
                    Button { showWorkouts = true } label: {
                        HealthStatTile(
                            icon: "dumbbell.fill",
                            color: .purple,
                            label: "Workouts",
                            value: "\(hk.todayWorkoutCount) workout\(hk.todayWorkoutCount == 1 ? "" : "s")"
                        )
                    }
                    .buttonStyle(.plain)
                    if let v = hk.vo2Max {
                        HealthStatTile(icon: "lungs.fill", color: .cyan, label: "VO2 Max", value: String(format: "%.1f", v))
                    }
                    if let v = hk.weight {
                        HealthStatTile(icon: "scalemass.fill", color: .brown, label: "Weight", value: String(format: "%.1f kg", v))
                    }
                    if let v = hk.bodyFat {
                        HealthStatTile(icon: "percent", color: .pink, label: "Body Fat", value: String(format: "%.1f%%", v * 100))
                    }
                    if let v = hk.height {
                        HealthStatTile(icon: "arrow.up.and.down", color: .purple, label: "Height", value: String(format: "%.0f cm", v))
                    }
                }

                if hk.sleepHours == nil && hk.stepCount == nil && hk.restingHeartRate == nil {
                    Text("No Health data for today yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
        .cornerRadius(16)
        .padding(.horizontal)
        .sheet(isPresented: $showWorkouts) {
            NavigationStack {
                ZStack {
                    Color(red: 0.08, green: 0.12, blue: 0.15).ignoresSafeArea()
                    if hk.recentWorkouts.isEmpty {
                        Text("No recent workouts")
                            .foregroundColor(.gray)
                    } else {
                        List(hk.recentWorkouts, id: \.uuid) { workout in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.workoutActivityType.name)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                HStack(spacing: 12) {
                                    Text("\(Int((workout.duration / 60).rounded())) min")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if let kcal = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
                                        Text(String(format: "%.0f kcal", kcal))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(workout.startDate, format: .dateTime.day().month(.abbreviated))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .listRowBackground(Color(red: 0.08, green: 0.12, blue: 0.15))
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
                .navigationTitle("Recent Workouts")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showWorkouts = false }
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }
}

extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .swimming: return "Swimming"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength Training"
        case .traditionalStrengthTraining: return "Strength Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .crossTraining: return "Cross Training"
        case .hiking: return "Hiking"
        default: return "Workout"
        }
    }
}

private struct HealthStatTile: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            Spacer()
        }
        .padding(10)
        .background(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
        .cornerRadius(10)
    }
}
