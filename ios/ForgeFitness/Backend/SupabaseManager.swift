import Foundation
import Supabase

enum SupabaseConfigurationError: LocalizedError {
    case fileNotFound
    case invalidFile
    case invalidURL
    case missingAnonKey
    case placeholderValues
    case environmentMismatch
    case unsafeProductionConnection

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            "The environment Supabase configuration was not found."
        case .invalidFile:
            "The environment Supabase configuration could not be decoded."
        case .invalidURL:
            "The Supabase URL is missing or invalid."
        case .missingAnonKey:
            "The Supabase anonymous key is missing."
        case .placeholderValues:
            "The environment configuration still contains placeholder values."
        case .environmentMismatch:
            "The Supabase configuration does not match this build environment."
        case .unsafeProductionConnection:
            "A non-production build cannot connect to production."
        }
    }
}

final class SupabaseManager {
    let client: SupabaseClient

    init(bundle: Bundle = .main) throws {
        let buildEnvironment = AppEnvironment.build
        guard let fileURL = bundle.url(
            forResource: buildEnvironment.configurationResource,
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
        guard configuration.environment == buildEnvironment else {
            throw SupabaseConfigurationError.environmentMismatch
        }

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

        let productionProjectRef = bundle.object(
            forInfoDictionaryKey: "ForgeProductionProjectRef"
        ) as? String
        if !buildEnvironment.isProduction,
           let productionProjectRef,
           url.host?.hasPrefix("\(productionProjectRef).") == true {
            throw SupabaseConfigurationError.unsafeProductionConnection
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
    let environment: AppEnvironment
    let url: String
    let anonKey: String
}

enum SupabaseDebugLogger {
    static func logConfigurationError(_ error: Error) {
        let nsError = error as NSError
        LoggingService.shared.log(
            "supabase_configuration_failed",
            category: .errors,
            level: .fault,
            metadata: LogMetadata([
                "error_type": String(describing: type(of: error)),
                "error_domain": nsError.domain,
                "error_code": "\(nsError.code)",
                "environment": AppEnvironment.build.rawValue
            ])
        )
    }
}
