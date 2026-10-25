import Foundation

enum PasswordPolicy {
    static func isValid(_ password: String) -> Bool {
        password.count >= 8
            && password.range(of: "[0-9]", options: .regularExpression) != nil
            && password.range(of: "[A-Z]", options: .regularExpression) != nil
            && password.range(of: "[a-z]", options: .regularExpression) != nil
    }
}
