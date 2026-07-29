import Foundation
import Supabase

final class ExerciseService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchExercises() async throws -> [Exercise] {
        let records: [LiveExerciseRecord] = try await client
            .from("exercises")
            .select(
                "id,name,category,hockey_category,primary_muscles,secondary_muscles,equipment,difficulty,video_url,instruction_steps,common_mistakes,coach_tips_list,substitutions"
            )
            .eq("is_active", value: true)
            .order("name")
            .execute()
            .value

        return records.compactMap(\.exercise)
    }
}

private struct LiveExerciseRecord: Decodable {
    let id: UUID
    let name: String
    let category: String
    let hockeyCategory: String?
    let primaryMuscles: [String]
    let secondaryMuscles: [String]
    let equipment: [String]
    let difficulty: String?
    let videoURL: String?
    let instructionSteps: [String]
    let commonMistakes: [String]
    let coachTips: [String]
    let substitutions: [String]

    var exercise: Exercise? {
        guard let category = ExerciseCategory(rawValue: category),
              let hockeyValue = hockeyCategory,
              let hockeyCategory = HockeyExerciseCategory(
                rawValue: hockeyValue
              ),
              let difficultyValue = difficulty,
              let difficulty = ExerciseDifficulty(
                rawValue: difficultyValue
              ) else {
            return nil
        }

        return Exercise(
            id: id,
            name: name,
            category: category,
            hockeyCategory: hockeyCategory,
            primaryMuscles: primaryMuscles.compactMap(MuscleGroup.init),
            secondaryMuscles: secondaryMuscles.compactMap(MuscleGroup.init),
            equipment: equipment.compactMap(Equipment.init),
            difficulty: difficulty,
            videoURL: videoURL.flatMap(URL.init(string:)),
            instructions: instructionSteps,
            commonMistakes: commonMistakes,
            coachTips: coachTips,
            substitutions: substitutions
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, name, category, equipment, difficulty, substitutions
        case hockeyCategory = "hockey_category"
        case primaryMuscles = "primary_muscles"
        case secondaryMuscles = "secondary_muscles"
        case videoURL = "video_url"
        case instructionSteps = "instruction_steps"
        case commonMistakes = "common_mistakes"
        case coachTips = "coach_tips_list"
    }
}
