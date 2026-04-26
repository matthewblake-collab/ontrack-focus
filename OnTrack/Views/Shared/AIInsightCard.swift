import SwiftUI

struct AIInsightCard: View {
    @State private var viewModel = AIInsightViewModel()
    let userId: String

    private var nextRefreshText: String {
        var cal = Calendar.current
        cal.timeZone = TimeZone.current
        let now = Date()
        var components = cal.dateComponents([.year, .month, .day], from: now)
        components.hour = 18
        components.minute = 0
        components.second = 0
        let todaySixPM = cal.date(from: components)!
        if now < todaySixPM {
            let fmt = DateFormatter()
            fmt.dateFormat = "h:mm a"
            return "Refreshes at \(fmt.string(from: todaySixPM))"
        } else {
            var tomorrowComponents = cal.dateComponents([.year, .month, .day], from: now)
            tomorrowComponents.hour = 18
            tomorrowComponents.minute = 0
            tomorrowComponents.second = 0
            let tomorrowSixPM = cal.date(byAdding: .day, value: 1, to: cal.date(from: tomorrowComponents)!)!
            let fmt = DateFormatter()
            fmt.dateFormat = "h:mm a"
            return "Refreshes at \(fmt.string(from: tomorrowSixPM)) tomorrow"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI Wellness Insight")
                    .font(.headline)
                Spacer()
            }

            if viewModel.isLoading {
                HStack {
                    ProgressView()
                    Text("Generating your insight...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)

            } else if !viewModel.insight.isEmpty {
                Text(viewModel.insight)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text(nextRefreshText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: { viewModel.load(userId: userId, forceRefresh: true) }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }

            } else if let error = viewModel.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.red)

                Button(action: { viewModel.load(userId: userId) }) {
                    Label("Try Again", systemImage: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.purple)
                }

            } else {
                Text("Get a personalised insight based on your last 7 days.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button(action: { viewModel.load(userId: userId) }) {
                    Label("Generate Insight", systemImage: "sparkles")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.purple)
                        .cornerRadius(20)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
        .onAppear { viewModel.load(userId: userId) }
    }
}
