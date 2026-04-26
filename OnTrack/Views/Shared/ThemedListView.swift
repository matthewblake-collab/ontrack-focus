import SwiftUI

extension View {
    func themedList(_ themeManager: ThemeManager) -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(themeManager.backgroundColour())
    }

    func themedRow(_ themeManager: ThemeManager) -> some View {
        self
            .listRowBackground(themeManager.cardColour())
    }
}
