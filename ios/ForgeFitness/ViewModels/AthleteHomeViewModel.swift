import Combine

@MainActor
final class AthleteHomeViewModel: ObservableObject {
    let greeting = "Good Morning, Yegor"

    let todaysWorkout = WorkoutSummary(
        title: "Lower Body Power",
        detail: "Explosive strength and acceleration",
        duration: "45 min",
        intensity: "High"
    )

    let recoveryScore = 82
    let workoutStreak = 6

    let quickStats = [
        QuickStat(title: "Workouts", value: "12", symbol: "figure.strengthtraining.traditional"),
        QuickStat(title: "Training", value: "8.5h", symbol: "clock"),
        QuickStat(title: "Personal Bests", value: "3", symbol: "trophy")
    ]

    let recentActivities = [
        ActivitySummary(
            title: "Upper Body Strength",
            detail: "Yesterday · 52 min",
            symbol: "dumbbell"
        ),
        ActivitySummary(
            title: "Speed & Agility",
            detail: "Monday · 38 min",
            symbol: "figure.run"
        )
    ]

    let upcomingTests = [
        TestingSummary(
            title: "20-Meter Sprint",
            date: "August 2",
            symbol: "stopwatch"
        ),
        TestingSummary(
            title: "Vertical Jump",
            date: "August 6",
            symbol: "arrow.up.to.line"
        )
    ]

}

struct WorkoutSummary {
    let title: String
    let detail: String
    let duration: String
    let intensity: String
}

struct QuickStat: Identifiable {
    let title: String
    let value: String
    let symbol: String

    var id: String { title }
}

struct ActivitySummary: Identifiable {
    let title: String
    let detail: String
    let symbol: String

    var id: String { title }
}

struct TestingSummary: Identifiable {
    let title: String
    let date: String
    let symbol: String

    var id: String { title }
}
