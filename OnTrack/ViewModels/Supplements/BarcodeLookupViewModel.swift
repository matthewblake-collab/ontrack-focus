import Foundation
import Observation
import Supabase

/// Resolves a scanned product barcode to a `ResolvedProduct` for pre-filling
/// AddSupplementView. Resolution chain:
///  1. Local cache — `products` table WHERE barcode = scanned value.
///  2. Cache miss — `barcode-lookup` Edge Function (hits Open Food Facts, writes
///     the result back into `products`, returns it).
///  3. Still nothing — returns nil; the caller leaves the form for manual entry.
@MainActor
@Observable
final class BarcodeLookupViewModel {
    var isResolving = false
    var errorMessage: String?

    /// Lightweight projection of `products` — never decode into a full model
    /// (per SCHEMA_RULES) since the Edge Function may return a partial row.
    struct ResolvedProduct: Decodable {
        let id: UUID
        let product_name: String
        let serving_size: Double?
        let serving_units: String?
        let dosage_form: String?
        let source: String?
    }

    private struct BarcodeRequest: Encodable { let barcode: String }

    func resolve(barcode: String) async -> ResolvedProduct? {
        let code = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return nil }

        isResolving = true
        errorMessage = nil
        defer { isResolving = false }

        // Step 1 — local products cache. Prefer au_seed canonical rows with a real
        // serving_size over OFF-cached rows: OFF's serving_quantity is a sachet/pack
        // count for many AU supplements (e.g. Triple Magnesium = "1 sachet"), not
        // the actual mg dose. The au_seed contributor table carries the real dose.
        do {
            let hits: [ResolvedProduct] = try await supabase
                .from("products")
                .select("id, product_name, serving_size, serving_units, dosage_form, source")
                .eq("barcode", value: code)
                .limit(5)
                .execute()
                .value
            if let auSeed = hits.first(where: { $0.source == "au_seed" && $0.serving_size != nil }) {
                return auSeed
            }
            if let hit = hits.first { return hit }
        } catch {
            // Non-fatal — fall through to the remote lookup.
        }

        // Step 2 — Edge Function → Open Food Facts → write-back. Function returns
        // a JSON product row on success, or the literal `null` on a miss.
        do {
            let resolved: ResolvedProduct? = try await supabase.functions.invoke(
                "barcode-lookup",
                options: FunctionInvokeOptions(body: BarcodeRequest(barcode: code))
            )
            return resolved
        } catch {
            // Function not deployed, OFF down, decode failure — all non-fatal.
            errorMessage = "Couldn't look up that barcode — enter the details manually."
            return nil
        }
    }
}
