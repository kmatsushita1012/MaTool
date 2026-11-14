import Dependencies
import Shared
import Testing
@preconcurrency import AWSCognitoIdentityProvider
@testable import Backend

struct CognitoAuthManagerUnitTests {
    private func service(
        recorder: CognitoCallRecorder,
        username: String? = "district",
        role: String? = "district",
        failOn: String? = nil
    ) -> CognitoAuthService {
        let attributes = role.map { [CognitoIdentityProviderClientTypes.AttributeType(
            name: "custom:role", value: $0
        )] }
        return CognitoAuthService(
            create: { request in
                await recorder.create(request)
                if failOn == "create" { throw TestError.intentional }
                return .init(user: .init(attributes: attributes, username: username))
            },
            disable: { request in
                await recorder.disable(request)
                if failOn == "disable" { throw TestError.intentional }
                return .init()
            },
            delete: { request in
                await recorder.delete(request)
                if failOn == "delete" { throw TestError.intentional }
                return .init()
            },
            getByToken: { request in
                await recorder.getByToken(request)
                if failOn == "token" { throw TestError.intentional }
                return .init(userAttributes: attributes, username: username)
            },
            getByUsername: { request in
                await recorder.getByUsername(request)
                if failOn == "username" { throw TestError.intentional }
                return .init(userAttributes: attributes, username: username)
            }
        )
    }

    @Test("ユーザー作成でCognitoへ通知媒体・検証済みメール・districtロールを渡す")
    func createBuildsCorrectRequestAndParsesCreatedUser() async throws {
        let recorder = CognitoCallRecorder()
        let manager = CognitoAuthManager(service: service(recorder: recorder), userPoolId: "pool")

        let result = try await manager.create(username: "district", email: "admin@example.com")

        #expect(result == .district("district"))
        let request = try #require(await recorder.created.first)
        #expect(request.userPoolId == "pool")
        #expect(request.username == "district")
        #expect(request.desiredDeliveryMediums == [.email])
        #expect(request.forceAliasCreation == false)
        #expect(request.messageAction == nil)
        #expect(request.userAttributes?.first(where: { $0.name == "email" })?.value == "admin@example.com")
        #expect(request.userAttributes?.first(where: { $0.name == "email_verified" })?.value == "true")
        #expect(request.userAttributes?.first(where: { $0.name == "custom:role" })?.value == "district")
    }

    @Test("ユーザー作成応答のusername欠落を拒否する")
    func missingUsernameIsUnauthorized() async {
        let recorder = CognitoCallRecorder()
        let manager = CognitoAuthManager(
            service: service(recorder: recorder, username: nil), userPoolId: "pool"
        )
        await #expect(throws: Error.self) {
            _ = try await manager.create(username: "district", email: "admin@example.com")
        }
        #expect(await recorder.created.count == 1)
    }

    @Test("ユーザー作成応答にdistrictロールがなければ拒否する")
    func nonDistrictCreatedRoleIsUnauthorized() async {
        let recorder = CognitoCallRecorder()
        let manager = CognitoAuthManager(
            service: service(recorder: recorder, role: "region"), userPoolId: "pool"
        )
        await #expect(throws: Error.self) {
            _ = try await manager.create(username: "district", email: "admin@example.com")
        }
    }

    @Test("Cognito作成失敗を成功に変換せず伝播する")
    func createFailurePropagates() async {
        let recorder = CognitoCallRecorder()
        let manager = CognitoAuthManager(
            service: service(recorder: recorder, failOn: "create"), userPoolId: "pool"
        )
        await #expect(throws: TestError.intentional) {
            _ = try await manager.create(username: "district", email: "admin@example.com")
        }
    }

    @Test("削除は必ず同一ユーザーのDisableに成功してからDeleteを実行する")
    func deleteDisablesBeforeDeleting() async throws {
        let recorder = CognitoCallRecorder()
        let manager = CognitoAuthManager(service: service(recorder: recorder), userPoolId: "pool")

        try await manager.delete(username: "district")

        #expect(await recorder.operations == ["disable", "delete"])
        #expect(await recorder.disabled.first?.userPoolId == "pool")
        #expect(await recorder.disabled.first?.username == "district")
        #expect(await recorder.deleted.first?.userPoolId == "pool")
        #expect(await recorder.deleted.first?.username == "district")
    }

    @Test("Disable失敗なら実ユーザーをDeleteしない")
    func failedDisableNeverDeletesUser() async {
        let recorder = CognitoCallRecorder()
        let manager = CognitoAuthManager(
            service: service(recorder: recorder, failOn: "disable"), userPoolId: "pool"
        )
        await #expect(throws: TestError.intentional) {
            try await manager.delete(username: "district")
        }
        #expect(await recorder.operations == ["disable"])
    }

    @Test("Delete失敗は呼び出し元に伝播して順序を維持する")
    func deleteFailurePropagates() async {
        let recorder = CognitoCallRecorder()
        let manager = CognitoAuthManager(
            service: service(recorder: recorder, failOn: "delete"), userPoolId: "pool"
        )
        await #expect(throws: TestError.intentional) {
            try await manager.delete(username: "district")
        }
        #expect(await recorder.operations == ["disable", "delete"])
    }

    @Test("アクセストークンからdistrictロールとユーザーIDを取得する")
    func readsRoleByAccessToken() async throws {
        let recorder = CognitoCallRecorder()
        let manager = CognitoAuthManager(service: service(recorder: recorder), userPoolId: "pool")

        let result = try await manager.get(accessToken: "test-token")

        #expect(result == .district("district"))
        #expect(await recorder.tokens.first?.accessToken == "test-token")
        #expect(await recorder.operations == ["token"])
    }

    @Test("Cognito管理者APIからregionロールを本部権限に変換する")
    func readsHeadquarterRoleByUsername() async throws {
        let recorder = CognitoCallRecorder()
        let manager = CognitoAuthManager(
            service: service(recorder: recorder, username: "festival", role: "region"),
            userPoolId: "pool"
        )

        let result = try await manager.get(username: "festival")

        #expect(result == .headquarter("festival"))
        #expect(await recorder.names.first?.username == "festival")
        #expect(await recorder.names.first?.userPoolId == "pool")
    }

    @Test("未知のロールを管理者扱いせず拒否する")
    func rejectsUnknownRole() async {
        let recorder = CognitoCallRecorder()
        let manager = CognitoAuthManager(
            service: service(recorder: recorder, role: "super-admin"), userPoolId: "pool"
        )

        await #expect(throws: Error.self) {
            _ = try await manager.get(accessToken: "token")
        }
    }

    @Test("ロール属性が欠落またはusernameがnilなら不正認証とする")
    func rejectsMissingRoleOrUsername() async {
        for combination in [(nil as String?, "district" as String?), ("district", nil)] {
            let recorder = CognitoCallRecorder()
            let manager = CognitoAuthManager(
                service: service(recorder: recorder, username: combination.0, role: combination.1),
                userPoolId: "pool"
            )
            await #expect(throws: Error.self) {
                _ = try await manager.get(username: "district")
            }
        }
    }

    @Test("Cognitoの認証情報取得失敗をそのまま伝播する")
    func lookupFailuresPropagate() async {
        for operation in ["token", "username"] {
            let recorder = CognitoCallRecorder()
            let manager = CognitoAuthManager(
                service: service(recorder: recorder, failOn: operation),
                userPoolId: "pool"
            )
            await #expect(throws: TestError.intentional) {
                if operation == "token" {
                    _ = try await manager.get(accessToken: "token")
                } else {
                    _ = try await manager.get(username: "district")
                }
            }
        }
    }
}

private actor CognitoCallRecorder {
    private(set) var operations: [String] = []
    private(set) var created: [AdminCreateUserInput] = []
    private(set) var disabled: [AdminDisableUserInput] = []
    private(set) var deleted: [AdminDeleteUserInput] = []
    private(set) var tokens: [GetUserInput] = []
    private(set) var names: [AdminGetUserInput] = []

    func create(_ value: AdminCreateUserInput) {
        operations.append("create")
        created.append(value)
    }

    func disable(_ value: AdminDisableUserInput) {
        operations.append("disable")
        disabled.append(value)
    }

    func delete(_ value: AdminDeleteUserInput) {
        operations.append("delete")
        deleted.append(value)
    }

    func getByToken(_ value: GetUserInput) {
        operations.append("token")
        tokens.append(value)
    }

    func getByUsername(_ value: AdminGetUserInput) {
        operations.append("username")
        names.append(value)
    }
}
