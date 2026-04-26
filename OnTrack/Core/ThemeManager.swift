import SwiftUI
import Combine

enum AppTheme: String, CaseIterable, Identifiable {
    case teal = "teal"
    case blue = "blue"
    case green = "green"
    case orange = "orange"
    case purple = "purple"
    case red = "red"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .teal: return "Teal"
        case .blue: return "Blue"
        case .green: return "Green"
        case .orange: return "Orange"
        case .purple: return "Purple"
        case .red: return "Red"
        }
    }

    var primary: Color {
        switch self {
        case .teal: return Color(red: 0.08, green: 0.35, blue: 0.45)
        case .blue: return Color(red: 0.0, green: 0.32, blue: 0.75)
        case .green: return Color(red: 0.1, green: 0.5, blue: 0.2)
        case .orange: return Color(red: 0.8, green: 0.4, blue: 0.0)
        case .purple: return Color(red: 0.4, green: 0.1, blue: 0.7)
        case .red: return Color(red: 0.7, green: 0.1, blue: 0.1)
        }
    }

    var secondary: Color {
        switch self {
        case .teal: return Color(red: 0.15, green: 0.55, blue: 0.38)
        case .blue: return Color(red: 0.1, green: 0.55, blue: 0.85)
        case .green: return Color(red: 0.2, green: 0.7, blue: 0.3)
        case .orange: return Color(red: 0.9, green: 0.6, blue: 0.1)
        case .purple: return Color(red: 0.6, green: 0.3, blue: 0.9)
        case .red: return Color(red: 0.9, green: 0.3, blue: 0.2)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [primary, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

enum ColorSchemePreference: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

enum BackgroundStyle: String, CaseIterable, Identifiable {
    case appDefault = "appDefault"
    case colour = "colour"
    case custom = "custom"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .appDefault: return "App Default"
        case .colour: return "Colour"
        case .custom: return "Custom Photo"
        }
    }

    var icon: String {
        switch self {
        case .appDefault: return "photo.fill"
        case .colour: return "paintpalette.fill"
        case .custom: return "person.crop.square.fill"
        }
    }
}

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: AppTheme {
        didSet { UserDefaults.standard.set(currentTheme.rawValue, forKey: "appTheme") }
    }

    @Published var colorSchemePreference: ColorSchemePreference {
        didSet { UserDefaults.standard.set(colorSchemePreference.rawValue, forKey: "colorScheme") }
    }

    @Published var backgroundOpacity: Double {
        didSet { UserDefaults.standard.set(backgroundOpacity, forKey: "backgroundOpacity") }
    }

    @Published var cardOpacity: Double {
        didSet { UserDefaults.standard.set(cardOpacity, forKey: "cardOpacity") }
    }

    @Published var backgroundTheme: AppTheme {
        didSet { UserDefaults.standard.set(backgroundTheme.rawValue, forKey: "backgroundTheme") }
    }

    @Published var cardTheme: AppTheme {
        didSet { UserDefaults.standard.set(cardTheme.rawValue, forKey: "cardTheme") }
    }

    @Published var backgroundStyle: BackgroundStyle {
        didSet { UserDefaults.standard.set(backgroundStyle.rawValue, forKey: "backgroundStyle") }
    }

    @Published var customBackgroundImageData: Data? {
        didSet { UserDefaults.standard.set(customBackgroundImageData, forKey: "customBgData") }
    }

    private init() {
        let savedTheme = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.teal.rawValue
        let savedScheme = UserDefaults.standard.string(forKey: "colorScheme") ?? ColorSchemePreference.dark.rawValue
        let savedOpacity = UserDefaults.standard.double(forKey: "backgroundOpacity")
        let savedCardOpacity = UserDefaults.standard.double(forKey: "cardOpacity")
        let savedBgTheme = UserDefaults.standard.string(forKey: "backgroundTheme") ?? AppTheme.teal.rawValue
        let savedCardTheme = UserDefaults.standard.string(forKey: "cardTheme") ?? AppTheme.teal.rawValue
        let savedBgStyle = UserDefaults.standard.string(forKey: "backgroundStyle") ?? BackgroundStyle.appDefault.rawValue

        self.currentTheme = AppTheme(rawValue: savedTheme) ?? .teal
        self.colorSchemePreference = ColorSchemePreference(rawValue: savedScheme) ?? .system
        self.backgroundOpacity = savedOpacity == 0 ? 0.15 : savedOpacity
        self.cardOpacity = savedCardOpacity == 0 ? 0.05 : savedCardOpacity
        self.backgroundTheme = AppTheme(rawValue: savedBgTheme) ?? .teal
        self.cardTheme = AppTheme(rawValue: savedCardTheme) ?? .teal
        self.backgroundStyle = BackgroundStyle(rawValue: savedBgStyle) ?? .appDefault
        self.customBackgroundImageData = UserDefaults.standard.data(forKey: "customBgData")
    }

    func backgroundColour() -> Color {
        backgroundTheme.primary.opacity(backgroundOpacity)
    }

    func cardColour() -> Color {
        Color(red: 0.06, green: 0.09, blue: 0.12).opacity(0.88)
    }

    // MARK: - Cycling Background Image
    // Cycles every 5 days through backgrounds 1-23
    // background 1 = groups_background, backgrounds 2-23 = background_2 ... background_23

    private static let backgroundImageNames: [String] = [
        "groups_background",
        "backround_2", "backround_3", "backround_4", "backround_5",
        "backround_6", "backround_7", "backround_8", "backround_9", "backround_10",
        "backround_11", "backround_12", "backround_13", "backround_14", "backround_15",
        "backround_16", "backround_17", "backround_18", "backround_19", "backround_20",
        "backround_21", "backround_22", "backround_23"
    ]

    private static let cycleStartDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 30
        return Calendar.current.date(from: components) ?? Date()
    }()

    var currentBackgroundImage: String {
        let daysSinceStart = Calendar.current.dateComponents(
            [.day], from: Self.cycleStartDate, to: Date()
        ).day ?? 0
        let index = daysSinceStart % Self.backgroundImageNames.count
        return Self.backgroundImageNames[max(0, index)]
    }
}
