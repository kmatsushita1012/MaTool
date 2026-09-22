import Dependencies
import Shared

public struct AuthProvider: Sendable {
    public var initialize: @Sendable () throws -> Void
    public var signIn: @Sendable (_ username: String, _ password: String) async throws -> SignInResponse
    public var confirmSignIn: @Sendable (_ newPassword: String) async throws -> Void
    public var getUserRole: @Sendable () async throws -> UserRole
    public var getTokens: @Sendable () async throws -> String
    public var signOut: @Sendable () async throws -> Void
    public var changePassword: @Sendable (_ current: String, _ new: String) async throws -> Void
    public var resetPassword: @Sendable (_ username: String) async throws -> Void
    public var confirmResetPassword: @Sendable (_ username: String, _ newPassword: String, _ code: String) async throws -> Void
    public var updateEmail: @Sendable (_ newEmail: String) async throws -> UpdateEmailState
    public var confirmUpdateEmail: @Sendable (_ code: String) async throws -> Void

    public init(
        initialize: @escaping @Sendable () throws -> Void,
        signIn: @escaping @Sendable (String, String) async throws -> SignInResponse,
        confirmSignIn: @escaping @Sendable (String) async throws -> Void,
        getUserRole: @escaping @Sendable () async throws -> UserRole,
        getTokens: @escaping @Sendable () async throws -> String,
        signOut: @escaping @Sendable () async throws -> Void,
        changePassword: @escaping @Sendable (String, String) async throws -> Void,
        resetPassword: @escaping @Sendable (String) async throws -> Void,
        confirmResetPassword: @escaping @Sendable (String, String, String) async throws -> Void,
        updateEmail: @escaping @Sendable (String) async throws -> UpdateEmailState,
        confirmUpdateEmail: @escaping @Sendable (String) async throws -> Void
    ) {
        self.initialize = initialize
        self.signIn = signIn
        self.confirmSignIn = confirmSignIn
        self.getUserRole = getUserRole
        self.getTokens = getTokens
        self.signOut = signOut
        self.changePassword = changePassword
        self.resetPassword = resetPassword
        self.confirmResetPassword = confirmResetPassword
        self.updateEmail = updateEmail
        self.confirmUpdateEmail = confirmUpdateEmail
    }
}

public enum AuthProviderKey: DependencyKey {
    public static let liveValue: AuthProvider = DependencyConfiguration.missing("AuthProvider")
}

public extension DependencyValues {
    var authProvider: AuthProvider {
        get { self[AuthProviderKey.self] }
        set { self[AuthProviderKey.self] = newValue }
    }
}
