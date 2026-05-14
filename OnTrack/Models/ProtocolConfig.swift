import Foundation

struct ProtocolPhaseTemplate: Identifiable, Hashable {
    var id: String { "\(name)-\(weekStart)" }
    let name: String
    let weekStart: Int
    let weekEnd: Int
}

struct ProtocolTypeConfig: Identifiable, Hashable {
    var id: String { type }
    let type: String
    let displayName: String
    let emoji: String
    let description: String
    let trackedMarkers: [String]
    let suggestedDurationWeeks: Int
    let phases: [ProtocolPhaseTemplate]
    let suggestedSupplements: [String]
}

enum ProtocolConfig {

    // MARK: - TRT
    private static let trtPhases: [ProtocolPhaseTemplate] = [
        .init(name: "Titration",     weekStart: 1,  weekEnd: 4),
        .init(name: "First Bloods",  weekStart: 5,  weekEnd: 8),
        .init(name: "Adaptation",    weekStart: 9,  weekEnd: 12),
        .init(name: "Peak Window",   weekStart: 13, weekEnd: 18),
        .init(name: "Re-Eval",       weekStart: 19, weekEnd: 22),
        .init(name: "6-Month Mark",  weekStart: 23, weekEnd: 26)
    ]
    private static let trtConfig = ProtocolTypeConfig(
        type: "trt",
        displayName: "TRT",
        emoji: "💉",
        description: "Testosterone replacement. Track full hormone panel + key downstream markers across a 6-month cycle.",
        trackedMarkers: ["total_t","free_t","e2","lh","fsh","haematocrit","igf1","prolactin","psa","creatinine"],
        suggestedDurationWeeks: 26,
        phases: trtPhases,
        suggestedSupplements: ["Zinc","Magnesium","Vitamin D","Boron","Omega-3"]
    )

    // MARK: - Fat Loss
    private static let fatLossPhases: [ProtocolPhaseTemplate] = [
        .init(name: "Baseline",    weekStart: 1,  weekEnd: 2),
        .init(name: "Deficit",     weekStart: 3,  weekEnd: 8),
        .init(name: "Recomp",      weekStart: 9,  weekEnd: 12),
        .init(name: "Maintenance", weekStart: 13, weekEnd: 16)
    ]
    private static let fatLossConfig = ProtocolTypeConfig(
        type: "fat_loss",
        displayName: "Fat Loss",
        emoji: "🔥",
        description: "Metabolic dial-in across deficit and recomposition phases.",
        trackedMarkers: ["glucose","hba1c","insulin","total_chol","ldl","crp","tsh"],
        suggestedDurationWeeks: 16,
        phases: fatLossPhases,
        suggestedSupplements: ["L-Carnitine","Berberine","Caffeine","EGCG","Whey Protein"]
    )

    // MARK: - Hyrox
    private static let hyroxPhases: [ProtocolPhaseTemplate] = [
        .init(name: "Base Building", weekStart: 1,  weekEnd: 6),
        .init(name: "Build",         weekStart: 7,  weekEnd: 12),
        .init(name: "Race Prep",     weekStart: 13, weekEnd: 18),
        .init(name: "Taper",         weekStart: 19, weekEnd: 20)
    ]
    private static let hyroxConfig = ProtocolTypeConfig(
        type: "hyrox",
        displayName: "Hyrox",
        emoji: "🏃",
        description: "Hybrid race prep — endurance volume, strength density, taper.",
        trackedMarkers: ["ferritin","iron","crp","creatinine","haematocrit","cortisol"],
        suggestedDurationWeeks: 20,
        phases: hyroxPhases,
        suggestedSupplements: ["Creatine","Beta Alanine","Iron","Electrolytes","Omega-3"]
    )

    // MARK: - Muscle Gain
    private static let muscleGainPhases: [ProtocolPhaseTemplate] = [
        .init(name: "Foundation",            weekStart: 1,  weekEnd: 4),
        .init(name: "Progressive Overload",  weekStart: 5,  weekEnd: 10),
        .init(name: "Intensity Block",       weekStart: 11, weekEnd: 14),
        .init(name: "Deload",                weekStart: 15, weekEnd: 16)
    ]
    private static let muscleGainConfig = ProtocolTypeConfig(
        type: "muscle_gain",
        displayName: "Muscle Gain",
        emoji: "💪",
        description: "Progressive overload + caloric surplus across a 16-week block.",
        trackedMarkers: ["total_t","igf1","glucose","creatinine","crp"],
        suggestedDurationWeeks: 16,
        phases: muscleGainPhases,
        suggestedSupplements: ["Creatine","Whey Protein","Beta Alanine","Magnesium","Zinc"]
    )

    // MARK: - General Health
    private static let generalHealthPhases: [ProtocolPhaseTemplate] = [
        .init(name: "Baseline",     weekStart: 1, weekEnd: 4),
        .init(name: "Optimisation", weekStart: 5, weekEnd: 8),
        .init(name: "Maintenance",  weekStart: 9, weekEnd: 12)
    ]
    private static let generalHealthConfig = ProtocolTypeConfig(
        type: "general_health",
        displayName: "General Health",
        emoji: "🌿",
        description: "Baseline optimisation with quarterly bloodwork.",
        trackedMarkers: ["crp","glucose","total_chol","hdl","ldl","tsh"],
        suggestedDurationWeeks: 12,
        phases: generalHealthPhases,
        suggestedSupplements: ["Vitamin D","Omega-3","Magnesium","Multivitamin","Probiotic"]
    )

    // MARK: - Peptide Protocol
    private static let peptidePhases: [ProtocolPhaseTemplate] = [
        .init(name: "Loading",      weekStart: 1,  weekEnd: 4),
        .init(name: "Steady State", weekStart: 5,  weekEnd: 10),
        .init(name: "Wash-out",     weekStart: 11, weekEnd: 12)
    ]
    private static let peptideConfig = ProtocolTypeConfig(
        type: "peptide_protocol",
        displayName: "Peptide Protocol",
        emoji: "🧬",
        description: "Peptide cycles — flexible duration. Customise as needed.",
        trackedMarkers: ["igf1","glucose","crp","creatinine"],
        suggestedDurationWeeks: 12,
        phases: peptidePhases,
        suggestedSupplements: []
    )

    // MARK: - Hormonal Optimisation
    private static let hormonalPhases: [ProtocolPhaseTemplate] = [
        .init(name: "Initial",   weekStart: 1,  weekEnd: 4),
        .init(name: "Mid-cycle", weekStart: 5,  weekEnd: 12),
        .init(name: "Re-eval",   weekStart: 13, weekEnd: 16)
    ]
    private static let hormonalConfig = ProtocolTypeConfig(
        type: "hormonal_optimisation",
        displayName: "Hormonal Optimisation",
        emoji: "⚡",
        description: "Non-TRT hormonal protocols — clomid, enclomiphene, AI-only.",
        trackedMarkers: ["total_t","free_t","e2","lh","fsh","prolactin"],
        suggestedDurationWeeks: 16,
        phases: hormonalPhases,
        suggestedSupplements: ["Zinc","Magnesium","Vitamin D"]
    )

    // MARK: - Custom
    private static let customConfig = ProtocolTypeConfig(
        type: "custom",
        displayName: "Custom",
        emoji: "✨",
        description: "Define your own goal and markers.",
        trackedMarkers: [],
        suggestedDurationWeeks: 12,
        phases: [],
        suggestedSupplements: []
    )

    // MARK: - Aggregate
    static let all: [ProtocolTypeConfig] = [
        trtConfig,
        fatLossConfig,
        hyroxConfig,
        muscleGainConfig,
        generalHealthConfig,
        peptideConfig,
        hormonalConfig,
        customConfig
    ]

    static func config(for type: String) -> ProtocolTypeConfig? {
        all.first { $0.type == type }
    }

    static func currentPhase(for type: String, weekNumber: Int) -> ProtocolPhaseTemplate? {
        guard let cfg = config(for: type) else { return nil }
        return cfg.phases.first { weekNumber >= $0.weekStart && weekNumber <= $0.weekEnd }
    }

    static func nextPhase(for type: String, weekNumber: Int) -> ProtocolPhaseTemplate? {
        guard let cfg = config(for: type) else { return nil }
        return cfg.phases.first { $0.weekStart > weekNumber }
    }
}
