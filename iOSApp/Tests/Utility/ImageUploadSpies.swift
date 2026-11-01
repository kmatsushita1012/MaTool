import Foundation
import PhotosUI
import ComposableArchitecture
import Shared
import SwiftUI
import Testing
@testable import iOSApp

enum ImageUploadSpyError: Error, Equatable, LocalizedError {
    case unexpected(String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unexpected(let message), .failed(let message): message
        }
    }
}

actor PhotoLibraryClientSpy: PhotoLibraryClientProtocol {
    private let data: Data?
    private let failure: String?
    private(set) var loadCallCount = 0

    init(data: Data? = nil, failure: String? = nil) {
        self.data = data
        self.failure = failure
    }

    func loadImageData(from item: PhotosPickerItem) async throws -> Data? {
        loadCallCount += 1
        if let failure { throw ImageUploadSpyError.failed(failure) }
        return data
    }
}

actor UnconfiguredPhotoLibraryClientSpy: PhotoLibraryClientProtocol {
    func loadImageData(from item: PhotosPickerItem) async throws -> Data? {
        throw ImageUploadSpyError.unexpected("PhotoLibraryClient")
    }
}

final class ImageJPEGProcessingClientSpy: ImageJPEGProcessingClientProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private let output: Data
    private let failure: String?
    private var recordedInputs: [Data] = []

    var inputs: [Data] { lock.withLock { recordedInputs } }

    init(output: Data, failure: String? = nil) {
        self.output = output
        self.failure = failure
    }

    func makeJPEG(from data: Data) throws -> Data {
        lock.withLock { recordedInputs.append(data) }
        if let failure { throw ImageUploadSpyError.failed(failure) }
        return output
    }
}

struct UnconfiguredImageJPEGProcessingClientSpy: ImageJPEGProcessingClientProtocol {
    func makeJPEG(from data: Data) throws -> Data {
        throw ImageUploadSpyError.unexpected("ImageJPEGProcessingClient")
    }
}

actor ImageUploadDataFetcherSpy: ImageUploadDataFetcherProtocol {
    private let response: ImageUploadURLResponse
    private(set) var requests: [ImageUploadURLRequest] = []

    init(response: ImageUploadURLResponse) { self.response = response }

    func issueUploadURL(for request: ImageUploadURLRequest) async throws -> ImageUploadURLResponse {
        requests.append(request)
        return response
    }
}

actor UnconfiguredImageUploadDataFetcherSpy: ImageUploadDataFetcherProtocol {
    func issueUploadURL(for request: ImageUploadURLRequest) async throws -> ImageUploadURLResponse {
        throw ImageUploadSpyError.unexpected("ImageUploadDataFetcher")
    }
}

actor S3ImageUploadClientSpy: S3ImageUploadClientProtocol {
    struct Call: Equatable, Sendable {
        let url: String
        let data: Data
    }

    private let failure: String?
    private(set) var calls: [Call] = []

    init(failure: String? = nil) { self.failure = failure }

    func put(url: String, jpegData: Data) async throws {
        calls.append(Call(url: url, data: jpegData))
        if let failure { throw ImageUploadSpyError.failed(failure) }
    }
}

actor UnconfiguredS3ImageUploadClientSpy: S3ImageUploadClientProtocol {
    func put(url: String, jpegData: Data) async throws {
        throw ImageUploadSpyError.unexpected("S3ImageUploadClient")
    }
}

actor UploadImageUseCaseSpy: UploadImageUseCaseProtocol {
    struct UploadCall: Equatable, Sendable {
        let target: ImageUploadTarget
        let jpegData: Data
    }

    private let preparedData: Data
    private var nextPath: String
    private var preparationFailure: String?
    private var uploadFailure: String?
    private(set) var prepareInputs: [Data] = []
    private(set) var uploadCalls: [UploadCall] = []

    init(
        preparedData: Data = Data([0xFF, 0xD8, 0xFF, 0xD9]),
        path: String = "temporary/image.jpg",
        preparationFailure: String? = nil,
        uploadFailure: String? = nil
    ) {
        self.preparedData = preparedData
        self.nextPath = path
        self.preparationFailure = preparationFailure
        self.uploadFailure = uploadFailure
    }

    func prepareJPEG(from data: Data) async throws -> Data {
        prepareInputs.append(data)
        if let preparationFailure { throw ImageUploadSpyError.failed(preparationFailure) }
        return preparedData
    }

    func upload(target: ImageUploadTarget, jpegData: Data) async throws -> String {
        uploadCalls.append(UploadCall(target: target, jpegData: jpegData))
        if let uploadFailure { throw ImageUploadSpyError.failed(uploadFailure) }
        return nextPath
    }

    func failPreparation(with message: String?) { preparationFailure = message }
    func failUpload(with message: String?) { uploadFailure = message }
    func setPath(_ path: String) { nextPath = path }
}

actor UnconfiguredUploadImageUseCaseSpy: UploadImageUseCaseProtocol {
    func prepareJPEG(from data: Data) async throws -> Data {
        throw ImageUploadSpyError.unexpected("UploadImageUseCase.prepareJPEG")
    }

    func upload(target: ImageUploadTarget, jpegData: Data) async throws -> String {
        throw ImageUploadSpyError.unexpected("UploadImageUseCase.upload")
    }
}

actor SaveFestivalUseCaseSpy: SaveFestivalUseCaseProtocol {
    struct Call: Sendable {
        let festival: Festival
        let checkpoints: [Checkpoint]
        let hazardSections: [HazardSection]
    }

    private let failure: String?
    private(set) var calls: [Call] = []

    init(failure: String? = nil) { self.failure = failure }

    func callAsFunction(
        festival: Festival,
        checkpoints: [Checkpoint],
        hazardSections: [HazardSection],
        appState: Shared<AppState?>
    ) async throws -> FestivalPack {
        calls.append(Call(festival: festival, checkpoints: checkpoints, hazardSections: hazardSections))
        if let failure { throw ImageUploadSpyError.failed(failure) }
        return FestivalPack(festival: festival, checkpoints: checkpoints, hazardSections: hazardSections)
    }
}

actor UnconfiguredSaveFestivalUseCaseSpy: SaveFestivalUseCaseProtocol {
    func callAsFunction(
        festival: Festival,
        checkpoints: [Checkpoint],
        hazardSections: [HazardSection],
        appState: Shared<AppState?>
    ) async throws -> FestivalPack {
        throw ImageUploadSpyError.unexpected("SaveFestivalUseCase")
    }
}

actor SaveDistrictPackUseCaseSpy: SaveDistrictPackUseCaseProtocol {
    struct Call: Sendable {
        let district: District
        let performances: [Performance]
    }

    private let failure: String?
    private(set) var calls: [Call] = []

    init(failure: String? = nil) { self.failure = failure }

    func callAsFunction(
        district: District,
        performances: [Performance],
        appState: Shared<AppState?>
    ) async throws -> DistrictPack {
        calls.append(Call(district: district, performances: performances))
        if let failure { throw ImageUploadSpyError.failed(failure) }
        return DistrictPack(district: district, performances: performances)
    }
}

actor UnconfiguredSaveDistrictPackUseCaseSpy: SaveDistrictPackUseCaseProtocol {
    func callAsFunction(
        district: District,
        performances: [Performance],
        appState: Shared<AppState?>
    ) async throws -> DistrictPack {
        throw ImageUploadSpyError.unexpected("SaveDistrictPackUseCase")
    }
}
