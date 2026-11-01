import AppStoreServerLibrary
import Dependencies
import Foundation

enum AdvertisingEnvironmentKey: DependencyKey {
    static let liveValue = AdvertisingEnvironment()
}

extension DependencyValues {
    var advertisingEnvironment: AdvertisingEnvironment {
        get { self[AdvertisingEnvironmentKey.self] }
        set { self[AdvertisingEnvironmentKey.self] = newValue }
    }
}

struct AdvertisingEnvironment: Sendable {
    let maximumStoresPerOwner: Int
    let impressionTokenSecret: String
    let appStoreBundleId: String
    let appStoreAppId: Int64?
    let appStoreAPIKeyId: String
    let appStoreAPIIssuerId: String
    let appStoreAPIPrivateKeyBase64: String
    let appStoreEnvironment: AppStoreEnvironment
    let appleRootCertificates: [Data]
    let productCredits: [String: Int]
    let reportTopicARN: String

    init(environment supplied: [String: String]? = nil) {
        var environment = supplied ?? ProcessInfo.processInfo.environment
        if supplied == nil,
           let url = Bundle.module.url(forResource: ".env", withExtension: nil),
           let contents = try? String(contentsOf: url, encoding: .utf8) {
            for line in contents.split(whereSeparator: \.isNewline) {
                let value = line.trimmingCharacters(in: .whitespaces)
                guard !value.isEmpty, !value.hasPrefix("#"), let separator = value.firstIndex(of: "=") else { continue }
                let key = String(value[..<separator]).trimmingCharacters(in: .whitespaces)
                var setting = String(value[value.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
                if setting.count >= 2,
                   (setting.first == "\"" && setting.last == "\"") || (setting.first == "'" && setting.last == "'") {
                    setting.removeFirst()
                    setting.removeLast()
                }
                if environment[key] == nil { environment[key] = setting }
            }
        }
        maximumStoresPerOwner = max(1, Int(environment["ADVERTISEMENT_MAX_STORES_PER_OWNER"] ?? "10") ?? 10)
        impressionTokenSecret = environment["ADVERTISEMENT_IMPRESSION_TOKEN_SECRET"] ?? ""
        appStoreBundleId = environment["APP_STORE_BUNDLE_ID"] ?? ""
        appStoreAppId = environment["APP_STORE_APP_ID"].flatMap(Int64.init)
        appStoreAPIKeyId = environment["APP_STORE_API_KEY_ID"] ?? ""
        appStoreAPIIssuerId = environment["APP_STORE_API_ISSUER_ID"] ?? ""
        appStoreAPIPrivateKeyBase64 = environment["APP_STORE_API_PRIVATE_KEY_BASE64"] ?? ""
        appStoreEnvironment = environment["APP_STORE_ENVIRONMENT"]?.lowercased() == "production" ? .production : .sandbox
        appleRootCertificates = (environment["APPLE_ROOT_CA_CERTIFICATES_BASE64"] ?? "")
            .split(separator: ",")
            .compactMap { Data(base64Encoded: String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
        var credits: [String: Int] = [:]
        if let product = environment["STORE_CREDIT_PRODUCT_ID_500"], !product.isEmpty { credits[product] = 500 }
        if let product = environment["STORE_CREDIT_PRODUCT_ID_1000"], !product.isEmpty { credits[product] = 1_000 }
        productCredits = credits
        reportTopicARN = environment["ADVERTISEMENT_REPORT_TOPIC_ARN"] ?? ""
    }
}
