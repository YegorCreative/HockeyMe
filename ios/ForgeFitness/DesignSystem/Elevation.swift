import SwiftUI

enum AppElevation {
    case flat
    case raised
    case floating
}

private struct ElevationModifier: ViewModifier {
    let elevation: AppElevation

    func body(content: Content) -> some View {
        switch elevation {
        case .flat:
            content
        case .raised:
            content.shadow(
                color: .black.opacity(0.08),
                radius: 8,
                y: 3
            )
        case .floating:
            content.shadow(
                color: .black.opacity(0.14),
                radius: 16,
                y: 8
            )
        }
    }
}

extension View {
    func forgeElevation(_ elevation: AppElevation) -> some View {
        modifier(ElevationModifier(elevation: elevation))
    }
}
