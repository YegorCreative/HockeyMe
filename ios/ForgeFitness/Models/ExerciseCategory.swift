enum ExerciseCategory: String, CaseIterable, Identifiable, Hashable {
    case strength = "Strength"
    case power = "Power"
    case plyometrics = "Plyometrics"
    case coreStability = "Core Stability"
    case conditioning = "Conditioning"

    var id: Self { self }
}

enum HockeyExerciseCategory: String, CaseIterable, Identifiable, Hashable {
    case skatingStrength = "Skating Strength"
    case firstStepQuickness = "First-Step Quickness"
    case lateralPower = "Lateral Power"
    case groinResilience = "Groin Resilience"
    case posteriorChain = "Posterior Chain"
    case upperBodyStrength = "Upper-Body Strength"
    case trunkControl = "Trunk Control"
    case workCapacity = "Work Capacity"

    var id: Self { self }
}

enum ExerciseDifficulty: String, CaseIterable, Identifiable, Hashable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var id: Self { self }
}
