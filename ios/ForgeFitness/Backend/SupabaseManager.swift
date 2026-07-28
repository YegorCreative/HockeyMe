import Foundation
import Supabase

enum SupabaseConfigurationError: LocalizedError {
    case fileNotFound
    case invalidFile
    case invalidURL
    case missingAnonKey
    case placeholderValues

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
        case .placeholderValues:
            "SupabaseConfig.plist still contains placeholder values."
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

        let urlValue = configuration.url.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let anonKey = configuration.anonKey.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !Self.isPlaceholder(urlValue),
              !Self.isPlaceholder(anonKey) else {
            throw SupabaseConfigurationError.placeholderValues
        }

        guard let url = URL(string: urlValue),
              url.scheme == "https",
              url.host != nil,
              url.user == nil,
              url.password == nil else {
            throw SupabaseConfigurationError.invalidURL
        }

        guard !anonKey.isEmpty else {
            throw SupabaseConfigurationError.missingAnonKey
        }

        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey
        )
    }

    private static func isPlaceholder(_ value: String) -> Bool {
        let normalized = value.lowercased()
        return normalized.isEmpty
            || normalized.contains("your_project")
            || normalized.contains("your_supabase")
            || normalized.contains("placeholder")
    }
}

private struct SupabaseConfiguration: Decodable {
    let url: String
    let anonKey: String
}

enum SupabaseDebugLogger {
    static func logConfigurationError(_ error: Error) {
#if DEBUG
        let nsError = error as NSError
        print(
            "[Supabase Configuration] \(type(of: error)): "
                + "domain=\(nsError.domain), code=\(nsError.code), "
                + "message=\(error.localizedDescription)"
        )
#endif
    }
}
