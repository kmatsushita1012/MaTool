@testable import iOSApp

/// ネットワークを使うフェッチャーのテストで明示的に注入するトークン用Spy。
func tokenProvidingAuthProvider() -> AuthProvider {
    var client = AuthProviderSpy().client
    client.getTokens = { "unit-test-access-token" }
    return client
}
