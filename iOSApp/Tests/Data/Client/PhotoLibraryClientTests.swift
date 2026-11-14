import Dependencies
import Foundation
import PhotosUI
import SwiftUI
import Testing
@testable import iOSApp

struct PhotoLibraryClientTests {
    @Test("選択された PhotosPickerItem の画像データを読み込む")
    func loadsSelectedImageData() async throws {
        let expected = Data([1, 2, 3])
        let recordedIdentifier = ItemIdentifierSpy()
        let client = PhotoLibraryClient { item in
            await recordedIdentifier.record(item.itemIdentifier)
            return expected
        }

        let result = try await client.loadImageData(
            from: PhotosPickerItem(itemIdentifier: "selected-photo")
        )

        #expect(result == expected)
        #expect(await recordedIdentifier.value == "selected-photo")
    }
    @Test("画像データが存在しない場合はnilをそのまま返す")
    func missingImageDataReturnsNil() async throws {
        let client = PhotoLibraryClient { _ in nil }
        let result = try await client.loadImageData(
            from: PhotosPickerItem(itemIdentifier: "empty-photo")
        )
        #expect(result == nil)
    }

    @Test("画像の読み込み失敗は呼び出し元に伝播する")
    func imageLoadFailurePropagates() async {
        let client = PhotoLibraryClient { _ in throw PhotoLibraryTestError.failed }
        await #expect(throws: PhotoLibraryTestError.failed) {
            try await client.loadImageData(
                from: PhotosPickerItem(itemIdentifier: "unavailable-photo")
            )
        }
    }

    @Test("DependencyValuesに差し替えたPhotosPickerローダーを通してデータを取得する")
    func resolvesInjectedPhotoLibraryClient() async throws {
        let client = PhotoLibraryClient { _ in Data([0xAB, 0xCD]) }
        let data = try await withDependencies {
            $0.photoLibraryClient = client
        } operation: {
            @Dependency(\.photoLibraryClient) var resolvedClient
            return try await resolvedClient.loadImageData(
                from: PhotosPickerItem(itemIdentifier: "injected-photo")
            )
        }

        #expect(data == Data([0xAB, 0xCD]))
    }

}

private enum PhotoLibraryTestError: Error {
    case failed
}

private actor ItemIdentifierSpy {
    private(set) var value: String?
    func record(_ value: String?) { self.value = value }
}
