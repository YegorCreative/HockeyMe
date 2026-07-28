import Combine
import Foundation

@MainActor
final class WorkoutViewModel: ObservableObject {
    let todaysWorkout: Workout
    let upcomingWorkouts: [Workout]
    let completedWorkouts: [Workout]

    init(calendar: Calendar = .current, now: Date = Date()) {
        let today = calendar.startOfDay(for: now)

        todaysWorkout = Workout(
            title: "Lower Body Power",
            description: "Build explosive strength for faster first steps, stronger strides, and better balance through contact.",
            estimatedDurationMinutes: 45,
            scheduledDate: today,
            status: .scheduled,
            exercises: [
                Exercise(
                    name: "Trap Bar Deadlift",
                    sets: 4,
                    reps: "5",
                    restSeconds: 120,
                    coachNotes: "Drive through the floor and finish each rep tall."
                ),
                Exercise(
                    name: "Rear-Foot Elevated Split Squat",
                    sets: 3,
                    reps: "8 each side",
                    restSeconds: 75,
                    coachNotes: "Keep the front knee tracking over the toes."
                ),
                Exercise(
                    name: "Lateral Bounds",
                    sets: 3,
                    reps: "6 each side",
                    restSeconds: 60,
                    coachNotes: "Stick every landing before the next repetition."
                )
            ]
        )

        upcomingWorkouts = [
            Workout(
                title: "Upper Body Strength",
                description: "Develop upper-body strength and shoulder stability for puck protection and shooting power.",
                estimatedDurationMinutes: 50,
                scheduledDate: calendar.date(
                    byAdding: .day,
                    value: 2,
                    to: today
                ) ?? today,
                status: .scheduled,
                exercises: [
                    Exercise(
                        name: "Incline Dumbbell Press",
                        sets: 4,
                        reps: "8",
                        restSeconds: 90,
                        coachNotes: "Keep the shoulder blades set against the bench."
                    ),
                    Exercise(
                        name: "Half-Kneeling Cable Row",
                        sets: 3,
                        reps: "10 each side",
                        restSeconds: 60,
                        coachNotes: "Stay tall and avoid rotating through the torso."
                    )
                ]
            ),
            Workout(
                title: "Speed & Agility",
                description: "Improve acceleration, change of direction, and reactive footwork.",
                estimatedDurationMinutes: 40,
                scheduledDate: calendar.date(
                    byAdding: .day,
                    value: 4,
                    to: today
                ) ?? today,
                status: .scheduled,
                exercises: [
                    Exercise(
                        name: "10-Meter Acceleration",
                        sets: 5,
                        reps: "1",
                        restSeconds: 75,
                        coachNotes: "Attack the first three steps with a forward body angle."
                    ),
                    Exercise(
                        name: "5-10-5 Shuttle",
                        sets: 4,
                        reps: "1",
                        restSeconds: 90,
                        coachNotes: "Lower the hips before each change of direction."
                    )
                ]
            )
        ]

        completedWorkouts = [
            Workout(
                title: "Total Body Foundation",
                description: "A balanced strength session focused on movement quality and control.",
                estimatedDurationMinutes: 48,
                scheduledDate: calendar.date(
                    byAdding: .day,
                    value: -2,
                    to: today
                ) ?? today,
                status: .completed,
                exercises: [
                    Exercise(
                        name: "Goblet Squat",
                        sets: 3,
                        reps: "10",
                        restSeconds: 60,
                        coachNotes: "Maintain a tall chest throughout the movement."
                    ),
                    Exercise(
                        name: "Push-Up",
                        sets: 3,
                        reps: "12",
                        restSeconds: 45,
                        coachNotes: "Keep a straight line from shoulders to heels."
                    )
                ]
            ),
            Workout(
                title: "Mobility & Recovery",
                description: "Restore range of motion and reduce residual fatigue.",
                estimatedDurationMinutes: 30,
                scheduledDate: calendar.date(
                    byAdding: .day,
                    value: -4,
                    to: today
                ) ?? today,
                status: .completed,
                exercises: [
                    Exercise(
                        name: "Hip 90/90 Flow",
                        sets: 2,
                        reps: "8 each side",
                        restSeconds: 30,
                        coachNotes: "Move slowly and stay within a comfortable range."
                    ),
                    Exercise(
                        name: "Adductor Rock Back",
                        sets: 2,
                        reps: "10 each side",
                        restSeconds: 30,
                        coachNotes: "Keep the spine neutral as the hips move back."
                    )
                ]
            )
        ]
    }
}
