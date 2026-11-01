import Dependencies
import Foundation
import PhotosUI
import SwiftUI

protocol PhotoLibraryClientProtocol: Sendable {
    func loadImageData(from item: PhotosPickerItem) async throws -> Data?
}

struct PhotoLibraryClient: PhotoLibraryClientProtocol {
    private let loader: @Sendable (PhotosPickerItem) async throws -> Data?

    init(loader: @escaping @Sendable (PhotosPickerItem) async throws -> Data? = {
        try await $0.loadTransferable(type: Data.self)
    }) {
        self.loader = loader
    }

    func loadImageData(from item: PhotosPickerItem) async throws -> Data? {
        try await loader(item)
    }
}

enum PhotoLibraryClientKey: DependencyKey {
    static let liveValue: any PhotoLibraryClientProtocol = PhotoLibraryClient()
}

extension DependencyValues {
    var photoLibraryClient: any PhotoLibraryClientProtocol {
        get { self[PhotoLibraryClientKey.self] }
        set { self[PhotoLibraryClientKey.self] = newValue }
    }
}
