import Foundation
import Supabase

enum SupabaseConfigurationError: LocalizedError {
    case fileNotFound
    case invalidFile
    case invalidURL
    case missingAnonKey

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            "SupabaseConfig.plist was not found."
        case .invalidFile:
            "SupabaseConfig.plist could not be decoded."
        case .invalidURL:
            "The Supabase URL is missing or invalid."
        case .missingAnonKey:
            "The Supabase anonymous key is missing."
        }
    }
}

final class SupabaseManager {
    let client: SupabaseClient

    init(bundle: Bundle = .main) throws {
        guard let fileURL = bundle.url(
            forResource: "SupabaseConfig",
            withExtension: "plist"
        ) else {
            throw SupabaseConfigurationError.fileNotFound
        }

        let data = try Data(contentsOf: fileURL)

        guard let configuration = try? PropertyListDecoder().decode(
            SupabaseConfiguration.self,
            from: data
        ) else {
            throw SupabaseConfigurationError.invalidFile
        }

        guard let url = URL(string: configuration.url),
              url.scheme == "https",
              url.host != nil else {
            throw SupabaseConfigurationError.invalidURL
        }

        guard !configuration.anonKey.isEmpty else {
            throw SupabaseConfigurationError.missingAnonKey
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: configuration.anonKey
        )
    }
}

private struct SupabaseConfiguration: Decodable {
    let url: String
    let anonKey: String
}
