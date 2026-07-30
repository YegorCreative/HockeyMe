import Foundation

struct Exercise: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let category: ExerciseCategory
    let hockeyCategory: HockeyExerciseCategory
    let primaryMuscles: [MuscleGroup]
    let secondaryMuscles: [MuscleGroup]
    let equipment: [Equipment]
    let difficulty: ExerciseDifficulty
    let videoURL: URL?
    let instructions: [String]
    let commonMistakes: [String]
    let coachTips: [String]
    let substitutions: [String]

    init(
        id: UUID = UUID(),
        name: String,
        category: ExerciseCategory,
        hockeyCategory: HockeyExerciseCategory,
        primaryMuscles: [MuscleGroup],
        secondaryMuscles: [MuscleGroup],
        equipment: [Equipment],
        difficulty: ExerciseDifficulty,
        videoURL: URL?,
        instructions: [String],
        commonMistakes: [String],
        coachTips: [String],
        substitutions: [String]
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.hockeyCategory = hockeyCategory
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.equipment = equipment
        self.difficulty = difficulty
        self.videoURL = videoURL
        self.instructions = instructions
        self.commonMistakes = commonMistakes
        self.coachTips = coachTips
        self.substitutions = substitutions
    }
}
