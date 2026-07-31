import Foundation

enum MacBuildEnvironment: String {
    case debug = "Debug"
    case staging = "Staging"
    case production = "Production"

    static var current: Self {
#if DEBUG
        .debug
#elseif STAGING
        .staging
#else
        .production
#endif
    }

    var title: String { rawValue }
}

struct MacSupabaseConfiguration {
    let url: URL
    let publishableKey: String

    static func load(
        bundle: Bundle,
        environment: MacBuildEnvironment
    ) -> MacSupabaseConfiguration? {
        let resource = "SupabaseConfig-Mac-\(environment.rawValue)"
        guard let path = bundle.path(forResource: resource, ofType: "plist"),
              let dictionary = NSDictionary(contentsOfFile: path),
              let urlString = dictionary["SUPABASE_URL"] as? String,
              let url = URL(string: urlString),
              url.scheme == "https",
              let key = dictionary["SUPABASE_ANON_KEY"] as? String,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return MacSupabaseConfiguration(url: url, publishableKey: key)
    }

    func isAllowed(for environment: MacBuildEnvironment) -> Bool {
        let productionHost = "xconmgstbnfspqrwtlmh.supabase.co"
        switch environment {
        case .debug, .staging:
            return url.host != productionHost
        case .production:
            return url.host == productionHost
        }
    }
}
