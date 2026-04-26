import SwiftUI

struct SupplementDoseCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var resultDose: String

    @State private var vialSize: String = ""
    @State private var vialUnit: DoseUnit = .mg
    @State private var bacWater: String = ""
    @State private var desiredDose: String = ""
    @State private var doseUnit: DoseUnit = .mcg
    @State private var result: CalculationResult? = nil
    @State private var showResult = false

    enum DoseUnit: String, CaseIterable {
        case mcg = "mcg"
        case mg = "mg"
        var toMcg: Double { self == .mcg ? 1.0 : 1000.0 }
    }

    struct CalculationResult {
        let units: Double
        let ml: Double
        let concentrationMcgPerMl: Double
        let concentrationMcgPerUnit: Double
        let totalMcg: Double
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    step1Card
                    step2Card
                    step3Card
                    calculateButton
                    if showResult, let r = result {
                        resultCard(r)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    Spacer(minLength: 40)
                }
                .padding()
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showResult)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(spacing: 6) {
            Image(systemName: "eyedropper.halffull")
                .font(.system(size: 32))
                .foregroundColor(.blue)
            Text("Supplement Dose Calculator")
                .font(.title2.bold())
            Text("Enter your vial details to calculate the exact dose to draw")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private var step1Card: some View {
        inputCard(title: "Step 1 — Vial Size", icon: "cylinder") {
            HStack(spacing: 12) {
                TextField("e.g. 10", text: $vialSize)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                Picker("Unit", selection: $vialUnit) {
                    ForEach(DoseUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
            }
            Text("Total amount of supplement in the vial")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    private var step2Card: some View {
        inputCard(title: "Step 2 — BAC Water Added", icon: "drop") {
            HStack {
                TextField("e.g. 2", text: $bacWater)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                Text("ml").foregroundColor(.secondary).frame(width: 30)
            }
            Text("How much bacteriostatic water you added")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    private var step3Card: some View {
        inputCard(title: "Step 3 — Desired Dose", icon: "syringe") {
            HStack(spacing: 12) {
                TextField("e.g. 5", text: $desiredDose)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                Picker("Unit", selection: $doseUnit) {
                    ForEach(DoseUnit.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
            }
            Text("The dose you want to inject")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    private var calculateButton: some View {
        Button(action: calculate) {
            HStack {
                Image(systemName: "function")
                Text("Calculate").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canCalculate ? Color.blue : Color.gray.opacity(0.3))
            .foregroundColor(canCalculate ? .white : .secondary)
            .cornerRadius(14)
        }
        .disabled(!canCalculate)
    }

    @ViewBuilder
    private func inputCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundColor(.blue).frame(width: 20)
                Text(title).font(.headline)
            }
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private func resultCard(_ r: CalculationResult) -> some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                Text("Result").font(.headline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.green.opacity(0.1))

            Divider()

            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text(formatDose((Double(desiredDose) ?? 0) * doseUnit.toMcg))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    Text(doseLabel((Double(desiredDose) ?? 0) * doseUnit.toMcg))
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 70)

                VStack(spacing: 4) {
                    Text(formatUnits(r.units))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    Text("units")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 70)

                VStack(spacing: 4) {
                    Text(formatMl(r.ml))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    Text("ml")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 20)

            Divider()

            VStack(spacing: 12) {
                resultRow(label: "Concentration", value: "\(formatNum(r.concentrationMcgPerMl)) mcg/ml")
                resultRow(label: "Per unit (IU)", value: "\(formatNum(r.concentrationMcgPerUnit)) mcg")
                resultRow(label: "Total in vial", value: "\(formatNum(r.totalMcg)) mcg")
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("How this was calculated:")
                    .font(.caption.bold()).foregroundColor(.secondary)
                Text(explanationText(r))
                    .font(.caption).foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGroupedBackground))

            Divider()

            Button {
                let doseMcg = (Double(desiredDose) ?? 0) * doseUnit.toMcg
                resultDose = "\(formatDose(doseMcg)) \(doseLabel(doseMcg)) | \(formatUnits(r.units)) units | \(formatMl(r.ml)) ml"
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Use this dose").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .clipped()
    }

    private func resultRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.secondary).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline.bold())
        }
    }

    var canCalculate: Bool {
        guard let v = Double(vialSize), let b = Double(bacWater), let d = Double(desiredDose) else { return false }
        return v > 0 && b > 0 && d > 0
    }

    func calculate() {
        guard let vialVal = Double(vialSize),
              let bacVal = Double(bacWater),
              let doseVal = Double(desiredDose) else { return }

        let totalMcg = vialVal * vialUnit.toMcg
        let doseMcg = doseVal * doseUnit.toMcg
        let mcgPerMl = totalMcg / bacVal
        let mcgPerUnit = mcgPerMl / 100.0
        let ml = doseMcg / mcgPerMl
        let units = ml * 100.0

        result = CalculationResult(
            units: units,
            ml: ml,
            concentrationMcgPerMl: mcgPerMl,
            concentrationMcgPerUnit: mcgPerUnit,
            totalMcg: totalMcg
        )
        showResult = true
        hideKeyboard()
    }

    func explanationText(_ r: CalculationResult) -> String {
        let vialMcg = (Double(vialSize) ?? 0) * vialUnit.toMcg
        let bac = Double(bacWater) ?? 0
        let dose = (Double(desiredDose) ?? 0) * doseUnit.toMcg
        return "Vial: \(formatNum(vialMcg)) mcg in \(formatNum(bac)) ml = \(formatNum(r.concentrationMcgPerMl)) mcg/ml. Each unit = \(formatNum(r.concentrationMcgPerUnit)) mcg. To get \(formatNum(dose)) mcg, draw \(formatUnits(r.units)) units (\(formatMl(r.ml)) ml)."
    }

    func formatDose(_ mcg: Double) -> String {
        if mcg >= 1000 {
            let mg = mcg / 1000.0
            if mg == mg.rounded() { return String(format: "%.0f", mg) }
            return String(format: "%.1f", mg)
        }
        if mcg == mcg.rounded() { return String(format: "%.0f", mcg) }
        return String(format: "%.1f", mcg)
    }

    func doseLabel(_ mcg: Double) -> String {
        return mcg >= 1000 ? "mg" : "mcg"
    }

    func formatUnits(_ n: Double) -> String {
        if n >= 10 { return String(format: "%.0f", n) }
        if n >= 1 { return String(format: "%.1f", n) }
        return String(format: "%.2f", n)
    }

    func formatMl(_ n: Double) -> String {
        if n < 0.01 { return String(format: "%.3f", n) }
        return String(format: "%.2f", n)
    }

    func formatNum(_ n: Double) -> String {
        if n == n.rounded() && n < 10000 { return String(format: "%.0f", n) }
        return String(format: "%.2f", n)
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
