import CryptoKit
import Foundation
import Supabase

enum FeatureFlagAudience: String, Codable {
    case all
    case `internal`
    case beta
}

struct FeatureFlag: Codable, Identifiable, Equatable {
    let id: UUID
    let key: String
    let enabled: Bool
    let environments: [AppEnvironment]
    let audience: FeatureFlagAudience
    let rolloutPercentage: Int
    let minimumVersion: String?
    let payload: [String: String]

    enum CodingKeys: String, CodingKey {
        case id, key, enabled, environments, audience, payload
        case rolloutPercentage = "rollout_percentage"
        case minimumVersion = "minimum_version"
    }
}

struct FeatureFlagContext: Sendable {
    let userID: UUID?
    let isInternalUser: Bool
    let isBetaUser: Bool

    static let anonymous = FeatureFlagContext(
        userID: nil,
        isInternalUser: false,
        isBetaUser: false
    )
}

enum FeatureFlagEvaluator {
    static func isEnabled(
        _ flag: FeatureFlag?,
        key: String,
        environment: AppEnvironment,
        context: FeatureFlagContext,
        appVersion: String
    ) -> Bool {
        guard let flag,
              flag.enabled,
              flag.environments.contains(environment),
              meetsAudience(flag.audience, context: context),
              meetsMinimumVersion(
                  appVersion,
                  minimum: flag.minimumVersion
              ) else {
            return false
        }
        if flag.rolloutPercentage >= 100 { return true }
        guard flag.rolloutPercentage > 0,
              let userID = context.userID else {
            return false
        }
        return bucket(key: key, userID: userID)
            < flag.rolloutPercentage
    }

    private static func meetsAudience(
        _ audience: FeatureFlagAudience,
        context: FeatureFlagContext
    ) -> Bool {
        switch audience {
        case .all: true
        case .internal: context.isInternalUser
        case .beta: context.isInternalUser || context.isBetaUser
        }
    }

    private static func bucket(key: String, userID: UUID) -> Int {
        let digest = SHA256.hash(
            data: Data("\(key):\(userID.uuidString)".utf8)
        )
        let prefix = digest.prefix(8).map {
            String(format: "%02x", $0)
        }.joined()
        return Int(UInt64(prefix, radix: 16) ?? 0) % 100
    }

    private static func meetsMinimumVersion(
        _ version: String,
        minimum: String?
    ) -> Bool {
        guard let minimum, !minimum.isEmpty else { return true }
        return version.compare(
            minimum,
            options: .numeric
        ) != .orderedAscending
    }
}

actor FeatureFlagService {
    private let client: SupabaseClient
    private let environment: AppEnvironment
    private let defaults: UserDefaults
    private let cacheKey: String
    private var flags: [String: FeatureFlag] = [:]

    init(
        client: SupabaseClient,
        environment: AppEnvironment = .build,
        defaults: UserDefaults = .standard
    ) {
        self.client = client
        self.environment = environment
        self.defaults = defaults
        cacheKey = "feature_flags_\(environment.rawValue)"

        if let data = defaults.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(
               [FeatureFlag].self,
               from: data
           ) {
            flags = Dictionary(uniqueKeysWithValues: cached.map {
                ($0.key, $0)
            })
        }
    }

    func refresh() async throws {
        let values: [FeatureFlag] = try await client
            .from("feature_flags")
            .select(
                "id,key,enabled,environments,audience,"
                    + "rollout_percentage,minimum_version,payload"
            )
            .contains("environments", value: [environment.rawValue])
            .execute()
            .value
        flags = Dictionary(uniqueKeysWithValues: values.map {
            ($0.key, $0)
        })
        if let data = try? JSONEncoder().encode(values) {
            defaults.set(data, forKey: cacheKey)
        }
        LoggingService.shared.log(
            "feature_flags_refreshed",
            category: .application,
            metadata: LogMetadata(["flag_count": "\(values.count)"])
        )
    }

    func isEnabled(
        _ key: String,
        context: FeatureFlagContext = .anonymous,
        appVersion: String = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0"
    ) -> Bool {
        FeatureFlagEvaluator.isEnabled(
            flags[key],
            key: key,
            environment: environment,
            context: context,
            appVersion: appVersion
        )
    }

    func payload(for key: String) -> [String: String] {
        flags[key]?.payload ?? [:]
    }

}
