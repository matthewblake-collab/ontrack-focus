import Foundation
import Combine
import Supabase

final class SupplementViewModel: ObservableObject {
    @Published var supplements: [Supplement] = []
    @Published var todaysLogs: [SupplementLog] = []
    @Published var supplementLogs: [SupplementLog] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    @Published var newName = ""
    @Published var newDoseAmount = ""
    @Published var newDoseUnits = "g"
    @Published var newTiming = SupplementTiming.morning
    @Published var newDaysOfWeek = "everyday"
    @Published var newNotes = ""
    @Published var newReminderEnabled = false
    @Published var newCustomTime = Date()
    @Published var newStockQuantity = ""
    @Published var newStockUnits = ""
    @Published var newStartDateEnabled: Bool = false
    @Published var newStartDate: Date = Date()
    @Published var newInProtocol: Bool = true

    func prefillFromKnowledgeItem(_ item: KnowledgeItem) {
        newName = item.title
        newInProtocol = true
        newNotes = item.description

        // Parse dosage string e.g. "2mg", "500 mcg", "1.5 g"
        if let dosage = item.dosage {
            let cleaned = dosage.trimmingCharacters(in: .whitespaces)
            let units = ["mcg", "mg", "ml", "IU", "g"]
            var matched = false
            for unit in units {
                if cleaned.lowercased().hasSuffix(unit) {
                    let numberPart = cleaned.dropLast(unit.count).trimmingCharacters(in: .whitespaces)
                    newDoseAmount = numberPart
                    newDoseUnits = unit
                    matched = true
                    break
                }
                // handle space-separated e.g. "500 mcg"
                let parts = cleaned.components(separatedBy: " ")
                if parts.count == 2 && parts[1].lowercased() == unit {
                    newDoseAmount = parts[0]
                    newDoseUnits = unit
                    matched = true
                    break
                }
            }
            if !matched {
                newDoseAmount = cleaned
            }
        }
    }

    var protocolSupplements: [Supplement] {
        supplements.filter { $0.inProtocol }
    }

    var todaysSupplements: [Supplement] {
        let today = Calendar.current.component(.weekday, from: Date())
        return protocolSupplements.filter { supplement in
            guard supplement.isActive else { return false }
            // Exclude if start date is in the future
            if let startDateStr = supplement.startDate {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                if let startDate = f.date(from: startDateStr) {
                    let todayStart = Calendar.current.startOfDay(for: Date())
                    if startDate > todayStart { return false }
                }
            }
            if supplement.daysOfWeek == "everyday" { return true }
            let days = supplement.daysOfWeek.split(separator: ",").map { String($0) }
            return days.contains(String(today))
        }
    }

    func isTaken(_ supplement: Supplement) -> Bool {
        todaysLogs.first { $0.supplementId == supplement.id }?.taken ?? false
    }

    func isLowStock(_ supplement: Supplement) -> Bool {
        guard let qty = supplement.stockQuantity else { return false }
        let dose = supplement.doseAmount ?? 1.0
        return (qty / dose) < 7
    }

    func fetchSupplements(userId: UUID) async {
        // Bug 4: removed isLoading toggles to coalesce publishes. Previously the
        // flag flip caused a pre-data re-render wave that showed empty rows
        // before the real data arrived.
        errorMessage = nil
        do {
            let result: [Supplement] = try await supabase
                .from("supplements")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("is_active", value: true)
                .order("created_at", ascending: true)
                .execute()
                .value
            self.supplements = result
            await fetchTodaysLogs(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchSupplementLogs(userId: UUID) async {
        do {
            let result: [SupplementLog] = try await supabase
                .from("supplement_logs")
                .select()
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            self.supplementLogs = result
        } catch {
            print("Error fetching supplement logs: \(error)")
        }
    }

    func logSupplement(_ supplement: Supplement, date: Date, userId: UUID) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let ds = formatter.string(from: date)
        do {
            let inserted: SupplementLog = try await supabase
                .from("supplement_logs")
                .upsert([
                    "supplement_id": supplement.id.uuidString,
                    "user_id": userId.uuidString,
                    "taken_at": ds,
                    "taken": "true"
                ], onConflict: "supplement_id,user_id,taken_at")
                .select()
                .single()
                .execute()
                .value
            if let idx = supplementLogs.firstIndex(where: { $0.supplementId == supplement.id && $0.takenAt == ds }) {
                supplementLogs[idx] = inserted
            } else {
                supplementLogs.append(inserted)
            }
            await deductStock(supplement: supplement)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unlogSupplement(_ supplement: Supplement, date: Date, userId: UUID) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let ds = formatter.string(from: date)
        guard let existing = supplementLogs.first(where: { $0.supplementId == supplement.id && $0.takenAt == ds }) else { return }
        do {
            try await supabase
                .from("supplement_logs")
                .delete()
                .eq("id", value: existing.id.uuidString)
                .execute()
            supplementLogs.removeAll { $0.id == existing.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchTodaysLogs(userId: UUID) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        do {
            let result: [SupplementLog] = try await supabase
                .from("supplement_logs")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("taken_at", value: today)
                .execute()
                .value
            self.todaysLogs = result
        } catch {
            print("Error fetching logs: \(error)")
        }
    }

    func toggleTaken(supplement: Supplement, userId: UUID) async {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let currentlyTaken = isTaken(supplement)

        do {
            let _: SupplementLog = try await supabase
                .from("supplement_logs")
                .upsert([
                    "supplement_id": supplement.id.uuidString,
                    "user_id": userId.uuidString,
                    "taken_at": today,
                    "taken": (!currentlyTaken).description
                ], onConflict: "supplement_id,user_id,taken_at")
                .select()
                .single()
                .execute()
                .value
            await fetchTodaysLogs(userId: userId)
            if !currentlyTaken {
                await deductStock(supplement: supplement)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func formatTime(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    func addSupplement(userId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            struct NewSupplement: Encodable {
                let userId: UUID
                let name: String
                let timing: String
                let daysOfWeek: String
                let notes: String?
                let reminderEnabled: Bool
                let isActive: Bool
                let inProtocol: Bool
                let stockQuantity: Double?
                let stockUnits: String?
                let doseAmount: Double?
                let doseUnits: String?
                let startDate: String?
                let customTime: String?
                enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case name, timing
                    case daysOfWeek = "days_of_week"
                    case notes
                    case reminderEnabled = "reminder_enabled"
                    case isActive = "is_active"
                    case inProtocol = "in_protocol"
                    case stockQuantity = "stock_quantity"
                    case stockUnits = "stock_units"
                    case doseAmount = "dose_amount"
                    case doseUnits = "dose_units"
                    case startDate = "start_date"
                    case customTime = "custom_time"
                }
            }

            let stockQty = newStockQuantity.isEmpty ? nil : Double(newStockQuantity)
            let doseAmt = newDoseAmount.isEmpty ? nil : Double(newDoseAmount)
            let startDateFormatter = DateFormatter()
            startDateFormatter.dateFormat = "yyyy-MM-dd"
            let payload = NewSupplement(
                userId: userId,
                name: newName,
                timing: newTiming.rawValue,
                daysOfWeek: newDaysOfWeek,
                notes: newNotes.isEmpty ? nil : newNotes,
                reminderEnabled: newReminderEnabled,
                isActive: true,
                inProtocol: newInProtocol,
                stockQuantity: stockQty,
                stockUnits: (stockQty != nil && !newStockUnits.isEmpty) ? newStockUnits : nil,
                doseAmount: doseAmt,
                doseUnits: doseAmt != nil ? newDoseUnits : nil,
                startDate: newStartDateEnabled ? startDateFormatter.string(from: newStartDate) : nil,
                customTime: newTiming == .custom ? Self.formatTime(newCustomTime) : nil
            )

            let _: Supplement = try await supabase
                .from("supplements")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value
            await fetchSupplements(userId: userId)
            resetForm()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deductStock(supplement: Supplement) async {
        guard let currentQty = supplement.stockQuantity, currentQty > 0 else { return }
        let deduction = supplement.doseAmount ?? 1.0
        let newQty = currentQty - deduction
        do {
            try await supabase
                .from("supplements")
                .update(["stock_quantity": newQty])
                .eq("id", value: supplement.id.uuidString)
                .execute()
            if let idx = supplements.firstIndex(where: { $0.id == supplement.id }) {
                supplements[idx].stockQuantity = newQty
            }
        } catch {
            print("Error deducting stock: \(error)")
        }
    }

    func updateSupplement(supplement: Supplement, userId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            let doseAmt = newDoseAmount.isEmpty ? nil : Double(newDoseAmount)
            let stockQty = newStockQuantity.isEmpty ? nil : Double(newStockQuantity)
            let updateDateFormatter = DateFormatter()
            updateDateFormatter.dateFormat = "yyyy-MM-dd"
            try await supabase
                .from("supplements")
                .update([
                    "name": newName,
                    "timing": newTiming.rawValue,
                    "notes": newNotes.isEmpty ? nil : newNotes,
                    "dose_amount": doseAmt.map { String($0) },
                    "dose_units": doseAmt != nil ? newDoseUnits : nil,
                    "stock_quantity": stockQty.map { String($0) },
                    "stock_units": (stockQty != nil && !newStockUnits.isEmpty) ? newStockUnits : nil,
                    "start_date": newStartDateEnabled ? updateDateFormatter.string(from: newStartDate) : nil,
                    "custom_time": newTiming == .custom ? Self.formatTime(newCustomTime) : nil
                ] as [String: String?])
                .eq("id", value: supplement.id.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()
            await fetchSupplements(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteSupplement(id: UUID, userId: UUID) async {
        supplements.removeAll { $0.id == id }
        NotificationManager.shared.cancelSupplementReminder(supplementId: id)
        do {
            try await supabase
                .from("supplements")
                .update(["is_active": "false"])
                .eq("id", value: id.uuidString)
                .execute()
        } catch {
            errorMessage = error.localizedDescription
            await fetchSupplements(userId: userId)
        }
    }

    func updateProtocol(supplement: Supplement, inProtocol: Bool, timing: SupplementTiming, daysOfWeek: String, reminderEnabled: Bool, userId: UUID) async {
        struct ProtocolUpdate: Encodable {
            let inProtocol: Bool
            let timing: String
            let daysOfWeek: String
            let reminderEnabled: Bool
            enum CodingKeys: String, CodingKey {
                case inProtocol = "in_protocol"
                case timing
                case daysOfWeek = "days_of_week"
                case reminderEnabled = "reminder_enabled"
            }
        }
        do {
            try await supabase
                .from("supplements")
                .update(ProtocolUpdate(inProtocol: inProtocol, timing: timing.rawValue, daysOfWeek: daysOfWeek, reminderEnabled: reminderEnabled))
                .eq("id", value: supplement.id.uuidString)
                .eq("user_id", value: userId.uuidString)
                .execute()
            await fetchSupplements(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetForm() {
        newName = ""
        newDoseAmount = ""
        newDoseUnits = "g"
        newTiming = .morning
        newDaysOfWeek = "everyday"
        newNotes = ""
        newReminderEnabled = false
        newCustomTime = Date()
        newStockQuantity = ""
        newStockUnits = ""
        newStartDateEnabled = false
        newStartDate = Date()
        newInProtocol = false
    }
}
