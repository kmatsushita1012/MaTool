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
}

private actor ItemIdentifierSpy {
    private(set) var value: String?
    func record(_ value: String?) { self.value = value }
}
