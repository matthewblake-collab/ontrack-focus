import SwiftUI

/// Quick-Log "supplement taken" mini-sheet. Tap a supplement from today's stack to
/// mark it taken, or scan a barcode: if it's already in the stack, mark it taken;
/// if not, offer "Add to stack & log" (a minimal off-protocol add). No form, no
/// extra screens. Reuses `SupplementViewModel.logSupplement`.
struct QuickLogSupplementSheet: View {
    @ObservedObject var supplementVM: SupplementViewModel
    let userId: UUID?
    let onComplete: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var showScanner = false
    @State private var barcodeVM = BarcodeLookupViewModel()
    @State private var pendingProduct: BarcodeLookupViewModel.ResolvedProduct?
    @State private var pendingCode: String?
    @State private var loggedIds: Set<UUID> = []
    @State private var statusMessage: String?

    private let cardColor = Color(red: 0.08, green: 0.12, blue: 0.15).opacity(0.92)

    private var todayStr: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }

    private var todaysSupps: [Supplement] {
        supplementVM.protocolSupplements.filter { $0.isScheduled(on: Date()) }
    }

    private func isLogged(_ s: Supplement) -> Bool {
        loggedIds.contains(s.id) ||
        supplementVM.supplementLogs.contains { $0.supplementId == s.id && $0.takenAt == todayStr && $0.taken }
    }

    var body: some View {
        ZStack {
            themeManager.backgroundColour().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Log a supplement")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.top, 8)

                    Button { showScanner = true } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "barcode.viewfinder")
                            Text("Scan barcode")
                                .fontWeight(.semibold)
                            Spacer()
                            if barcodeVM.isResolving { ProgressView().controlSize(.small).tint(.white) }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(cardColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    if let p = pendingProduct {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("“\(p.product_name)” isn't in your stack yet.")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Button {
                                Task { await addAndLog() }
                            } label: {
                                Text("Add to stack & log")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(themeManager.currentTheme.primary)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(14)
                        .background(cardColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Text("From my stack")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))

                    if todaysSupps.isEmpty {
                        Text("Nothing scheduled today — scan a barcode instead.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(todaysSupps) { s in
                                let done = isLogged(s)
                                Button {
                                    guard !done, let userId else { return }
                                    Task {
                                        await supplementVM.logSupplement(s, date: Date(), userId: userId)
                                        if supplementVM.errorMessage == nil {
                                            loggedIds.insert(s.id)
                                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                                        } else {
                                            statusMessage = supplementVM.errorMessage
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(s.name)
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(done ? themeManager.currentTheme.primary : .white.opacity(0.35))
                                    }
                                    .padding(14)
                                    .background(cardColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                                .disabled(done)
                            }
                        }
                    }

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button { onComplete() } label: {
                        Text("Done")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundStyle(.white)
                            .background(cardColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            guard let userId else { return }
            await supplementVM.fetchSupplements(userId: userId)
            await supplementVM.fetchSupplementLogs(userId: userId)
        }
        .sheet(isPresented: $showScanner) {
            BarcodeScannerSheet { code in
                Task { await handleScan(code) }
            }
        }
    }

    private func handleScan(_ code: String) async {
        statusMessage = nil
        pendingProduct = nil
        pendingCode = nil
        guard let userId else { return }

        if let inStack = supplementVM.supplements.first(where: { $0.barcodeScanned == code }) {
            await supplementVM.logSupplement(inStack, date: Date(), userId: userId)
            if supplementVM.errorMessage == nil {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onComplete()
            } else {
                statusMessage = supplementVM.errorMessage
            }
            return
        }

        if let p = await barcodeVM.resolve(barcode: code) {
            pendingProduct = p
            pendingCode = code
        } else {
            statusMessage = barcodeVM.errorMessage ?? "Not found — add it manually from the Supps tab."
        }
    }

    private func addAndLog() async {
        guard let p = pendingProduct, let code = pendingCode, let userId else { return }
        supplementVM.newName = p.product_name
        if let size = p.serving_size { supplementVM.newDoseAmount = formatDose(size) }
        if let u = p.serving_units, !u.isEmpty { supplementVM.newDoseUnits = u }
        supplementVM.newProductId = p.id
        supplementVM.newBarcodeScanned = code
        supplementVM.newInProtocol = false
        supplementVM.newDaysOfWeek = "everyday"
        let added = await supplementVM.addSupplement(userId: userId)
        guard let added else {
            statusMessage = supplementVM.errorMessage ?? "Couldn't add that supplement."
            return
        }
        await supplementVM.logSupplement(added, date: Date(), userId: userId)
        if supplementVM.errorMessage == nil {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onComplete()
        } else {
            statusMessage = supplementVM.errorMessage
        }
    }

    private func formatDose(_ v: Double) -> String {
        let r = (v * 100).rounded() / 100
        return r == r.rounded() ? String(Int(r)) : String(r)
    }
}
