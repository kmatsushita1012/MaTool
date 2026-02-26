import Shared

extension Error {
    func toAuthError() -> AuthError {
        .unknown(localizedDescription)
    }
}
