import Foundation
import Testing
@testable import Backend

struct EnvironmentTest {
    @Test("Lambdaでは関数の環境変数のみを使い.envを読まない")
    func lambdaUsesProcessEnvironmentOnly() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try "COGNITO_TEST_EMAIL=from-file@example.test\nEXTRA=from-file\n"
            .write(to: directory.appendingPathComponent(".env"), atomically: true, encoding: .utf8)

        let variables = Environment.resolvedVariables(
            processEnvironment: [
                "AWS_LAMBDA_FUNCTION_NAME": "MaToolAPIv2",
                "COGNITO_USER_POOL_ID": "lambda-pool"
            ],
            currentDirectoryPath: directory.path
        )

        #expect(variables["COGNITO_USER_POOL_ID"] == "lambda-pool")
        #expect(variables["COGNITO_TEST_EMAIL"] == nil)
        #expect(variables["EXTRA"] == nil)
    }

    @Test("ローカルではプロセス環境を優先しBackend/.envで不足分を補う")
    func localEnvironmentMergesProcessAndFileValues() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let backendDirectory = directory.appendingPathComponent("Backend", isDirectory: true)
        try FileManager.default.createDirectory(at: backendDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try "COGNITO_USER_POOL_ID=file-pool\nCOGNITO_TEST_EMAIL=file@example.test\n"
            .write(to: backendDirectory.appendingPathComponent(".env"), atomically: true, encoding: .utf8)

        let variables = Environment.resolvedVariables(
            processEnvironment: ["COGNITO_USER_POOL_ID": "process-pool"],
            currentDirectoryPath: directory.path
        )

        #expect(variables["COGNITO_USER_POOL_ID"] == "process-pool")
        #expect(variables["COGNITO_TEST_EMAIL"] == "file@example.test")
    }
}
