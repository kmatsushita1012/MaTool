import Dependencies
import Shared
import Testing
@testable import Backend

struct ImagePathFinalizerTests {
    @Test("Storeの2枚をすべて検証してから公開コピーする")
    func validatesBothStoreImagesBeforePublishingEither() async throws {
        let spy = ImageStorageClientSpy()
        let result = try await withDependencies {
            $0[ImageStorageClientKey.self] = spy
        } operation: {
            try await ImagePathFinalizer().finalizeStoreImages(
                incomingBanner: "temporary/stores/store-1/banner.jpg",
                currentBanner: nil,
                incomingInterstitial: "temporary/stores/store-1/interstitial.jpg",
                currentInterstitial: nil,
                storeId: "store-1"
            )
        }

        #expect(result.banner == "https://cdn.example.test/image.jpg?v=1")
        #expect(result.interstitial == "https://cdn.example.test/image.jpg?v=1")
        #expect(await spy.events == [
            "validate:temporary/stores/store-1/banner.jpg",
            "validate:temporary/stores/store-1/interstitial.jpg",
            "publish:temporary/stores/store-1/banner.jpg",
            "publish:temporary/stores/store-1/interstitial.jpg"
        ])
        #expect(await spy.publishCalls.map(\.1) == [
            "stores/store-1/banner.jpg",
            "stores/store-1/interstitial.jpg"
        ])
    }

    @Test("Storeの2枚目が不正なら1枚目も公開コピーしない")
    func rejectsInvalidStoreImageBeforePublishingEither() async {
        let bannerKey = "temporary/stores/store-1/banner.jpg"
        let interstitialKey = "temporary/stores/store-1/interstitial.jpg"
        let spy = ImageStorageClientSpy(validationFailures: [interstitialKey])

        await #expect(throws: Error.self) {
            try await withDependencies {
                $0[ImageStorageClientKey.self] = spy
            } operation: {
                try await ImagePathFinalizer().finalizeStoreImages(
                    incomingBanner: bannerKey,
                    currentBanner: nil,
                    incomingInterstitial: interstitialKey,
                    currentInterstitial: nil,
                    storeId: "store-1"
                )
            }
        }

        #expect(await spy.validationKeys == [bannerKey, interstitialKey])
        #expect(await spy.publishCalls.isEmpty)
        #expect(await spy.events == ["validate:\(bannerKey)", "validate:\(interstitialKey)"])
    }

    @Test("更新したvariantだけを公開し既存画像を保持する")
    func replacesOnlyTheSelectedVariantAfterPublish() async throws {
        let spy = ImageStorageClientSpy()
        let incoming = ImagePath(light: "temporary/festivals/festival-1/light.jpg", dark: "https://legacy.example/dark.jpg")
        let current = ImagePath(light: "https://cdn.example/old.jpg?v=4", dark: "https://legacy.example/dark.jpg")

        let result = try await withDependencies {
            $0[ImageStorageClientKey.self] = spy
        } operation: {
            try await ImagePathFinalizer().finalize(incoming: incoming, current: current, type: .festival, id: "festival-1")
        }

        #expect(result.light == "https://cdn.example.test/image.jpg?v=1")
        #expect(result.dark == current.dark)
        let calls = await spy.publishCalls
        #expect(calls.count == 1)
        #expect(calls.first?.0 == "temporary/festivals/festival-1/light.jpg")
        #expect(calls.first?.1 == "festivals/festival-1/light.jpg")
        #expect(calls.first?.2 == current.light)
        #expect(await spy.validationKeys == ["temporary/festivals/festival-1/light.jpg"])
        #expect(await spy.events == [
            "validate:temporary/festivals/festival-1/light.jpg",
            "publish:temporary/festivals/festival-1/light.jpg"
        ])
    }

    @Test("LightとDarkのどちらが不正でも検証完了前に公開しない")
    func validatesBothVariantsBeforePublishing() async {
        let lightKey = "temporary/festivals/festival-1/light.jpg"
        let darkKey = "temporary/festivals/festival-1/dark.jpg"
        let incoming = ImagePath(light: lightKey, dark: darkKey)
        let current = ImagePath(light: "https://cdn.example/light.jpg?v=3", dark: "https://cdn.example/dark.jpg?v=4")

        for invalidKey in [lightKey, darkKey] {
            let spy = ImageStorageClientSpy(validationFailures: [invalidKey])
            await #expect(throws: Error.self) {
                try await withDependencies {
                    $0[ImageStorageClientKey.self] = spy
                } operation: {
                    try await ImagePathFinalizer().finalize(
                        incoming: incoming,
                        current: current,
                        type: .festival,
                        id: "festival-1"
                    )
                }
            }

            let expectedValidationKeys = invalidKey == lightKey ? [lightKey] : [lightKey, darkKey]
            #expect(await spy.validationKeys == expectedValidationKeys)
            #expect(await spy.publishCalls.isEmpty)
            #expect(await spy.events == expectedValidationKeys.map { "validate:\($0)" })
        }
    }

    @Test("別対象の一時キーを拒否して公開処理を呼ばない")
    func rejectsMismatchedTemporaryKeyWithoutPublishing() async {
        let spy = ImageStorageClientSpy()
        await #expect(throws: Error.self) {
            try await withDependencies {
                $0[ImageStorageClientKey.self] = spy
            } operation: {
                try await ImagePathFinalizer().finalize(
                    incoming: .init(light: "temporary/festivals/another/light.jpg"),
                    current: .init(), type: .festival, id: "festival-1"
                )
            }
        }
        let calls = await spy.publishCalls
        #expect(calls.isEmpty)
    }

    @Test("別対象・別variant・外部URLを拒否する")
    func rejectsForeignVariantAndExternalPathsWithoutPublishing() async {
        for path in [
            "temporary/festivals/another/light.jpg",
            "temporary/festivals/festival-1/dark.jpg",
            "https://external.example/image.jpg"
        ] {
            let spy = ImageStorageClientSpy()
            await #expect(throws: Error.self) {
                try await withDependencies {
                    $0[ImageStorageClientKey.self] = spy
                } operation: {
                    try await ImagePathFinalizer().finalize(
                        incoming: .init(light: path),
                        current: .init(light: "https://cdn.example/old.jpg?v=9"),
                        type: .festival,
                        id: "festival-1"
                    )
                }
            }
            #expect(await spy.publishCalls.isEmpty)
            #expect(await spy.validationKeys.isEmpty)
        }
    }

    @Test("現在の公開URLをそのまま送れば変更として扱わない")
    func acceptsUnchangedCurrentPublicURLWithoutStorageCalls() async throws {
        let currentURL = "https://cdn.example/current.jpg?v=9"
        let spy = ImageStorageClientSpy()

        let result = try await withDependencies {
            $0[ImageStorageClientKey.self] = spy
        } operation: {
            try await ImagePathFinalizer().finalize(
                incoming: .init(light: currentURL),
                current: .init(light: currentURL),
                type: .festival,
                id: "festival-1"
            )
        }

        #expect(result.light == currentURL)
        #expect(await spy.validationKeys.isEmpty)
        #expect(await spy.publishCalls.isEmpty)
    }
}
