import Foundation

enum AppEnvironment: String, Codable {
    case debug
    case staging
    case production

    static var build: AppEnvironment {
#if STAGING
        .staging
#elseif DEBUG
        .debug
#else
        .production
#endif
    }

    var configurationResource: String {
        switch self {
        case .debug: "SupabaseConfig-Debug"
        case .staging: "SupabaseConfig-Staging"
        case .production: "SupabaseConfig-Production"
        }
    }

    var displayName: String {
        rawValue.uppercased()
    }

    var isProduction: Bool {
        self == .production
    }
}
