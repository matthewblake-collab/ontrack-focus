import Foundation
import Supabase

class AIInsightService {
    static let shared = AIInsightService()
    private let functionURL = "https://wqkisslixduowewuaiae.supabase.co/functions/v1/ai-insight"

    func generateInsight(prompt: String) async throws -> String {
        // Get the current session JWT to authenticate with the Edge Function
        guard let session = await supabase.auth.currentSession else {
            throw NSError(domain: "AIInsightService", code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        let jwt = session.accessToken

        var request = URLRequest(url: URL(string: functionURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let body: [String: Any] = ["prompt": prompt]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "AIInsightService", code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Server error \(http.statusCode)"])
        }

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["insight"] as? String {
            return text
        }

        throw NSError(domain: "AIInsightService", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
    }
}
