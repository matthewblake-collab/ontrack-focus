import Foundation
import Observation
import Supabase

// MARK: - Models

struct Challenge: Identifiable, Codable {
    let id: UUID
    let createdBy: UUID
    var title: String
    var description: String?
    var goalType: String
    var goalTarget: Double
    var goalUnit: String?
    var frequency: String?
    var startDate: Date?
    var endDate: Date?
    var acceptBy: Date
    var status: String
    var groupId: UUID?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, description, frequency, status
        case createdBy = "created_by"
        case title
        case goalType = "goal_type"
        case goalTarget = "goal_target"
        case goalUnit = "goal_unit"
        case startDate = "start_date"
        case endDate = "end_date"
        case acceptBy = "accept_by"
        case groupId = "group_id"
        case createdAt = "created_at"
    }
}

struct ChallengeInvite: Identifiable, Codable {
    let id: UUID
    let challengeId: UUID
    let inviteeId: UUID
    var status: String
    var respondedAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, status
        case challengeId = "challenge_id"
        case inviteeId = "invitee_id"
        case respondedAt = "responded_at"
        case createdAt = "created_at"
    }
}

// MARK: - ViewModel

@Observable
final class ChallengeViewModel {
    var challenges: [Challenge] = []
    var pendingInvites: [ChallengeInvite] = []
    var incomingChallenge: Challenge? = nil
    var incomingInvite: ChallengeInvite? = nil
    var isLoading = false
    var errorMessage: String?

    // Form state for creating a challenge
    var newTitle = ""
    var newDescription = ""
    var newGoalType = "habit"
    var newGoalTarget: Double = 1
    var newGoalUnit = ""
    var newFrequency = "weekly"
    var newStartDate = Date()
    var newEndDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    var newAcceptBy = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    var newGroupId: UUID? = nil
    var selectedInviteeIds: [String] = []

    func fetchMyChallenges(userId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result: [Challenge] = try await supabase
                .from("challenges")
                .select()
                .eq("created_by", value: userId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            challenges = result
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchPendingInvites(userId: UUID) async {
        do {
            let result: [ChallengeInvite] = try await supabase
                .from("challenge_invites")
                .select()
                .eq("invitee_id", value: userId.uuidString)
                .eq("status", value: "pending")
                .execute()
                .value
            pendingInvites = result
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchAcceptedChallenges(userId: UUID) async {
        do {
            let invites: [ChallengeInvite] = try await supabase
                .from("challenge_invites")
                .select()
                .eq("invitee_id", value: userId.uuidString)
                .eq("status", value: "accepted")
                .execute()
                .value

            guard !invites.isEmpty else { return }

            let challengeIds = invites.map { $0.challengeId.uuidString }
            let accepted: [Challenge] = try await supabase
                .from("challenges")
                .select()
                .in("id", values: challengeIds)
                .execute()
                .value

            let existingIds = Set(challenges.map { $0.id })
            let newOnes = accepted.filter { !existingIds.contains($0.id) }
            challenges.append(contentsOf: newOnes)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createChallenge(createdBy: UUID) async {
        do {
            let newChallenge = Challenge(
                id: UUID(),
                createdBy: createdBy,
                title: newTitle,
                description: newDescription.isEmpty ? nil : newDescription,
                goalType: newGoalType,
                goalTarget: newGoalTarget,
                goalUnit: newGoalUnit.isEmpty ? nil : newGoalUnit,
                frequency: newFrequency,
                startDate: newStartDate,
                endDate: newEndDate,
                acceptBy: newAcceptBy,
                status: "pending",
                groupId: newGroupId,
                createdAt: Date()
            )
            try await supabase
                .from("challenges")
                .insert(newChallenge)
                .execute()

            for inviteeId in selectedInviteeIds {
                let invite: [String: String] = [
                    "challenge_id": newChallenge.id.uuidString,
                    "invitee_id": inviteeId,
                    "status": "pending"
                ]
                try await supabase
                    .from("challenge_invites")
                    .insert(invite)
                    .execute()
            }

            await fetchMyChallenges(userId: createdBy)
            resetForm()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchLatestPendingInvite(userId: UUID) async {
        do {
            let invites: [ChallengeInvite] = try await supabase
                .from("challenge_invites")
                .select()
                .eq("invitee_id", value: userId.uuidString)
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value

            guard let invite = invites.first else {
                incomingInvite = nil
                incomingChallenge = nil
                return
            }

            let challenges: [Challenge] = try await supabase
                .from("challenges")
                .select()
                .eq("id", value: invite.challengeId.uuidString)
                .limit(1)
                .execute()
                .value

            incomingInvite = invite
            incomingChallenge = challenges.first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func respondToInvite(inviteId: UUID, accept: Bool, userId: UUID) async {
        do {
            try await supabase
                .from("challenge_invites")
                .update([
                    "status": accept ? "accepted" : "declined",
                    "responded_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: inviteId.uuidString)
                .execute()
            await fetchPendingInvites(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateChallenge(_ challenge: Challenge, title: String, description: String, goalType: String, goalTarget: Double, goalUnit: String, frequency: String, startDate: Date?, endDate: Date?, acceptBy: Date) async {
        do {
            struct ChallengeUpdate: Encodable {
                var title: String
                var description: String?
                var goalType: String
                var goalTarget: Double
                var goalUnit: String?
                var frequency: String
                var startDate: String?
                var endDate: String?
                var acceptBy: String
                enum CodingKeys: String, CodingKey {
                    case title, description, frequency
                    case goalType = "goal_type"
                    case goalTarget = "goal_target"
                    case goalUnit = "goal_unit"
                    case startDate = "start_date"
                    case endDate = "end_date"
                    case acceptBy = "accept_by"
                }
            }
            let fmt = ISO8601DateFormatter()
            let payload = ChallengeUpdate(
                title: title,
                description: description.isEmpty ? nil : description,
                goalType: goalType,
                goalTarget: goalTarget,
                goalUnit: goalUnit.isEmpty ? nil : goalUnit,
                frequency: frequency,
                startDate: startDate.map { fmt.string(from: $0) },
                endDate: endDate.map { fmt.string(from: $0) },
                acceptBy: fmt.string(from: acceptBy)
            )
            try await supabase
                .from("challenges")
                .update(payload)
                .eq("id", value: challenge.id.uuidString)
                .execute()
            if let idx = challenges.firstIndex(where: { $0.id == challenge.id }) {
                challenges[idx] = Challenge(
                    id: challenge.id,
                    createdBy: challenge.createdBy,
                    title: title,
                    description: description.isEmpty ? nil : description,
                    goalType: goalType,
                    goalTarget: goalTarget,
                    goalUnit: goalUnit.isEmpty ? nil : goalUnit,
                    frequency: frequency,
                    startDate: startDate,
                    endDate: endDate,
                    acceptBy: acceptBy,
                    status: challenge.status,
                    groupId: challenge.groupId,
                    createdAt: challenge.createdAt
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteChallenge(_ challenge: Challenge) async {
        do {
            try await supabase
                .from("challenge_invites")
                .delete()
                .eq("challenge_id", value: challenge.id.uuidString)
                .execute()
            try await supabase
                .from("challenges")
                .delete()
                .eq("id", value: challenge.id.uuidString)
                .execute()
            challenges.removeAll { $0.id == challenge.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetForm() {
        newTitle = ""
        newDescription = ""
        newGoalType = "habit"
        newGoalTarget = 1
        newGoalUnit = ""
        newFrequency = "weekly"
        newStartDate = Date()
        newEndDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        newAcceptBy = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        newGroupId = nil
        selectedInviteeIds = []
    }
}
