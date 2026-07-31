import SwiftUI

enum AppMotion {
    static let instant = Duration.milliseconds(100)
    static let quick = Duration.milliseconds(180)
    static let standard = Duration.milliseconds(280)
    static let deliberate = Duration.milliseconds(420)

    static let quickAnimation = Animation.easeOut(duration: 0.18)
    static let standardAnimation = Animation.easeInOut(duration: 0.28)
    static let spring = Animation.spring(
        duration: 0.42,
        bounce: 0.12
    )
}
