import SwiftUI

struct ChallengeDetailView: View {
    let challenge: Challenge
    let currentUserId: UUID
    let viewModel: ChallengeViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm = false
    @State private var showEditSheet = false

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
    private var isOwner: Bool { challenge.createdBy == currentUserId }

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {

                    ZStack {
                        Circle()
                            .fill(gold.opacity(0.15))
                            .frame(width: 100, height: 100)
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 44))
                            .foregroundColor(gold)
                    }
                    .padding(.top, 24)

                    Text(challenge.title)
                        .font(.title2.bold())
                        .foregroundColor(gold)
                        .multilineTextAlignment(.center)

                    if let desc = challenge.description {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        statCard(title: "Goal", value: "\(Int(challenge.goalTarget)) \(challenge.goalUnit ?? "")")
                        statCard(title: "Frequency", value: challenge.frequency?.capitalized ?? "—")
                        if let start = challenge.startDate {
                            statCard(title: "Start", value: start.formatted(date: .abbreviated, time: .omitted))
                        }
                        if let end = challenge.endDate {
                            statCard(title: "End", value: end.formatted(date: .abbreviated, time: .omitted))
                        }
                        statCard(title: "Accept By", value: challenge.acceptBy.formatted(date: .abbreviated, time: .shortened))
                        statCard(title: "Status", value: challenge.status.capitalized)
                    }
                    .padding(.horizontal)

                    if isOwner {
                        VStack(spacing: 12) {
                            Button {
                                showEditSheet = true
                            } label: {
                                Label("Edit Challenge", systemImage: "pencil")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(gold.opacity(0.4), lineWidth: 1)))
                            }

                            Button {
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete Challenge", systemImage: "trash")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92)).overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.red.opacity(0.4), lineWidth: 1)))
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Challenge")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .confirmationDialog("Delete this challenge?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteChallenge(challenge)
                    dismiss()
                }
            }
        } message: {
            Text("This will remove the challenge and all invites. This cannot be undone.")
        }
        .sheet(isPresented: $showEditSheet) {
            EditChallengeView(challenge: challenge, viewModel: viewModel, onDismiss: { showEditSheet = false })
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(gold.opacity(0.25), lineWidth: 1))
        )
    }
}
