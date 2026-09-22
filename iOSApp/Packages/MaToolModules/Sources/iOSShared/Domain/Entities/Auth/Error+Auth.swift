import Shared

extension Error {
    func toAppError() -> AppError {
        asAppError
    }
}
