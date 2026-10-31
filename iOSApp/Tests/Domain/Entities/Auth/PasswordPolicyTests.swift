import Testing
@testable import iOSApp

struct PasswordPolicyTests {
    @Test("長さと英大文字・英小文字・数字を満たしたパスワードを受け入れる")
    func acceptsPasswordThatMeetsAllRules() {
        #expect(PasswordPolicy.isValid("Festival1"))
    }

    @Test("必須条件を欠くパスワードを拒否する")
    func rejectsPasswordMissingARequiredRule() {
        #expect(!PasswordPolicy.isValid("festival1"))
        #expect(!PasswordPolicy.isValid("Festival"))
        #expect(!PasswordPolicy.isValid("Fest1"))
    }
}
