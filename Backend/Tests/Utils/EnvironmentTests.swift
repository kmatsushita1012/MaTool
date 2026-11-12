import Dependencies
import Foundation
import Testing
#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif
@testable import Backend

@Suite(.serialized)
struct EnvironmentTests {
    @Test("envの空行・コメント・他のキーを無視して正しい設定を抽出する")
    func parserIgnoresCommentsAndUnrelatedKeys() {
        let content = """

        # comment
        BROKEN
        OTHER_KEY=old
          COGNITO_USER_POOL_ID  =  ap-northeast-1_abc

        COGNITO_TEST_EMAIL = admin@example.com
        """
        #expect(Environment.value(for: "COGNITO_USER_POOL_ID", in: content) == "ap-northeast-1_abc")
        #expect(Environment.value(for: "COGNITO_TEST_EMAIL", in: content) == "admin@example.com")
        #expect(Environment.value(for: "UNKNOWN", in: content) == nil)
    }

    @Test("シングル・ダブルクォートを取り除き、値中のイコールを保持する")
    func parserHandlesBothQuoteStyles() {
        let content = """
        COGNITO_USER_POOL_ID = "ap-northeast-1_X=Y"
        COGNITO_TEST_EMAIL = 'admin+test@example.com'
        """
        #expect(Environment.value(for: "COGNITO_USER_POOL_ID", in: content) == "ap-northeast-1_X=Y")
        #expect(Environment.value(for: "COGNITO_TEST_EMAIL", in: content) == "admin+test@example.com")
    }

    @Test("途中の引用符と不揃いの引用符を意図せず削除しない")
    func parserDoesNotTrimUnmatchedQuotes() {
        let content = """
        KEY_A= "unmatched'
        KEY_B= one"two
        KEY_C= 'a'
        """
        #expect(Environment.value(for: "KEY_A", in: content) == "\"unmatched'")
        #expect(Environment.value(for: "KEY_B", in: content) == "one\"two")
        #expect(Environment.value(for: "KEY_C", in: content) == "a")
    }

    @Test("同じキーが複数ある場合は最初の値を採用する")
    func firstMatchingKeyWins() {
        let content = """
        KEY=first
        KEY=second
        """
        #expect(Environment.value(for: "KEY", in: content) == "first")
    }

    @Test("環境変数が提供された場合は設定ファイルより優先する")
    func liveValuesReadEnvironmentVariables() {
        let keys = ["COGNITO_USER_POOL_ID", "COGNITO_TEST_EMAIL"]
        let before = keys.map { key -> String? in
            guard let ptr = getenv(key) else { return nil }
            return String(cString: ptr)
        }
        defer {
            for (key, value) in zip(keys, before) {
                if let value {
                    setenv(key, value, 1)
                } else {
                    unsetenv(key)
                }
            }
        }
        setenv(keys[0], "test-pool", 1)
        setenv(keys[1], "test@example.com", 1)

        let result = Environment.liveValue
        #expect(result.cognitoPoolId == "test-pool")
        #expect(result.cognitoTestEmail == "test@example.com")

        let testValue = Environment.testValue
        #expect(testValue.cognitoPoolId == "test-pool")
        #expect(testValue.cognitoTestEmail == "test@example.com")
    }

    @Test("DIによる設定差し替えは正しく反映される")
    func dependencyCanBeReplacedWithoutLiveNetwork() {
        let selected = withDependencies {
            $0[Environment.self] = Environment(
                cognitoPoolId: "stub-pool", cognitoTestEmail: "stub@example.com"
            )
        } operation: {
            @Dependency(Environment.self) var env
            return env
        }

        #expect(selected.cognitoPoolId == "stub-pool")
        #expect(selected.cognitoTestEmail == "stub@example.com")
    }
}
