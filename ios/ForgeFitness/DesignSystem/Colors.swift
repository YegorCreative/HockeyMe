import SwiftUI

enum AppColors {
    static let primary = Color(
        light: UIColor(red: 0.06, green: 0.25, blue: 0.43, alpha: 1),
        dark: UIColor(red: 0.30, green: 0.65, blue: 0.94, alpha: 1)
    )
    static let primaryPressed = Color(
        light: UIColor(red: 0.04, green: 0.18, blue: 0.32, alpha: 1),
        dark: UIColor(red: 0.22, green: 0.53, blue: 0.80, alpha: 1)
    )
    static let secondary = Color(
        light: UIColor(red: 0.12, green: 0.46, blue: 0.72, alpha: 1),
        dark: UIColor(red: 0.38, green: 0.72, blue: 0.98, alpha: 1)
    )
    static let accent = Color(
        light: UIColor(red: 0.00, green: 0.61, blue: 0.82, alpha: 1),
        dark: UIColor(red: 0.25, green: 0.80, blue: 0.96, alpha: 1)
    )
    static let background = Color(.systemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)
    static let surface = Color(.secondarySystemBackground)
    static let elevatedSurface = Color(.tertiarySystemBackground)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(.tertiaryLabel)
    static let border = Color(.separator)
    static let borderStrong = Color(.opaqueSeparator)
    static let success = Color(
        light: UIColor(red: 0.08, green: 0.50, blue: 0.27, alpha: 1),
        dark: UIColor(red: 0.25, green: 0.78, blue: 0.43, alpha: 1)
    )
    static let warning = Color(
        light: UIColor(red: 0.82, green: 0.45, blue: 0.00, alpha: 1),
        dark: UIColor(red: 1.00, green: 0.69, blue: 0.22, alpha: 1)
    )
    static let error = Color(
        light: UIColor(red: 0.75, green: 0.10, blue: 0.12, alpha: 1),
        dark: UIColor(red: 1.00, green: 0.39, blue: 0.42, alpha: 1)
    )
    static let info = secondary
    static let onAccent = Color.white
    static let scrim = Color.black.opacity(0.32)
    static let chartPalette = [
        primary,
        accent,
        success,
        warning,
        Color.purple,
        Color.indigo
    ]
}

private extension Color {
    init(light: UIColor, dark: UIColor) {
        self.init(
            UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            }
        )
    }
}
