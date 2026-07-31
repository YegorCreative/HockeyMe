import SwiftUI

enum AppTypography {
    static let largeTitle = Font.largeTitle
    static let title = Font.title
    static let title2 = Font.title2
    static let title3 = Font.title3
    static let headline = Font.headline
    static let subheadline = Font.subheadline
    static let body = Font.body
    static let callout = Font.callout
    static let footnote = Font.footnote
    static let caption = Font.caption
    static let caption2 = Font.caption2

    static let metric = Font.system(
        .title,
        design: .rounded,
        weight: .bold
    )
    static let heroMetric = Font.system(
        .largeTitle,
        design: .rounded,
        weight: .bold
    )
}
