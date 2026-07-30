enum MuscleGroup: String, CaseIterable, Identifiable, Hashable, Codable {
    case quadriceps = "Quadriceps"
    case hamstrings = "Hamstrings"
    case glutes = "Glutes"
    case calves = "Calves"
    case adductors = "Adductors"
    case chest = "Chest"
    case shoulders = "Shoulders"
    case upperBack = "Upper Back"
    case lats = "Lats"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case core = "Core"
    case forearms = "Forearms"

    var id: Self { self }
}
