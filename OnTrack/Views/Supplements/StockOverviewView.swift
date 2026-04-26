import SwiftUI

struct StockOverviewView: View {
    @ObservedObject var viewModel: SupplementViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        List(viewModel.supplements) { supplement in
            NavigationLink(destination: SupplementDetailView(supplement: supplement, viewModel: viewModel)) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(supplement.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)

                        if let qty = supplement.stockQuantity {
                            let qtyStr = qty == qty.rounded() ? String(Int(qty)) : String(format: "%.1f", qty)
                            let stockLabel = supplement.stockUnits.map { "\(qtyStr) \($0)" } ?? qtyStr
                            Text("\(stockLabel) remaining")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        } else {
                            Text("No stock tracked")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.4))
                        }

                        if let doseAmount = supplement.doseAmount {
                            let doseStr = doseAmount == doseAmount.rounded() ? String(Int(doseAmount)) : String(format: "%.1f", doseAmount)
                            let doseLabel = supplement.doseUnits.map { "\(doseStr)\($0)" } ?? doseStr
                            Text("\(doseLabel) per dose")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }

                    Spacer()

                    if viewModel.isLowStock(supplement) {
                        Text("Low Stock")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 4)
            .listRowBackground(
                RoundedRectangle(cornerRadius: 12)
                    .fill(themeManager.cardColour())
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(themeManager.currentTheme.primary.opacity(0.4), lineWidth: 1)
                    )
                    .padding(.vertical, 2)
            )
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
