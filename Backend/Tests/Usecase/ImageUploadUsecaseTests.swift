import Dependencies
import Shared
import Testing
@testable import Backend

struct ImageUploadUsecaseTests {
    @Test("Festival本部本人だけがFestivalの署名URLを取得できる")
    func issuesFestivalUploadURLForOwningHeadquarter() async throws {
        let festival = Festival(
            id: "festival-1",
            name: "Festival",
            subname: "Headquarters",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let festivals = FestivalRepositorySpy(festivals: [festival])
        let districts = DistrictRepositorySpy()
        let images = ImageStorageClientSpy()
        let request = request(type: .festival, id: festival.id, variant: .light)

        let response = try await withDependencies {
            $0[FestivalRepositoryKey.self] = festivals
            $0[DistrictRepositoryKey.self] = districts
            $0[ImageStorageClientKey.self] = images
        } operation: {
            try await ImageUploadUsecase().issue(request, user: .headquarter(festival.id))
        }

        #expect(response.path == "temporary/festivals/festival-1/light.jpg")
        #expect(response.url == "https://s3.example.test/upload")
        #expect(await images.presignKeys == [response.path])
    }

    @Test("District本人だけがDistrictの署名URLを取得できる")
    func issuesDistrictUploadURLForOwningDistrict() async throws {
        let district = District(id: "district-1", name: "District", festivalId: "festival-1")
        let festivals = FestivalRepositorySpy()
        let districts = DistrictRepositorySpy(districts: [district])
        let images = ImageStorageClientSpy()
        let request = request(type: .district, id: district.id, variant: .dark)

        let response = try await withDependencies {
            $0[FestivalRepositoryKey.self] = festivals
            $0[DistrictRepositoryKey.self] = districts
            $0[ImageStorageClientKey.self] = images
        } operation: {
            try await ImageUploadUsecase().issue(request, user: .district(district.id))
        }

        #expect(response.path == "temporary/festivals/festival-1/districts/district-1/dark.jpg")
        #expect(await images.presignKeys == [response.path])
    }

    @Test("guest・別アカウント・別Role・不存在・Store・不正variant・MIMEでは署名しない")
    func rejectsUnauthorizedOrInvalidUploadURLRequestsBeforePresigning() async {
        let festival = Festival(
            id: "festival-1",
            name: "Festival",
            subname: "Headquarters",
            base: Coordinate(latitude: 35, longitude: 139)
        )
        let district = District(id: "district-1", name: "District", festivalId: festival.id)
        let festivalRepository = FestivalRepositorySpy(festivals: [festival])
        let districtRepository = DistrictRepositorySpy(districts: [district])
        let cases: [(ImageUploadURLRequest, UserRole)] = [
            (request(type: .festival, id: festival.id, variant: .light), .guest),
            (request(type: .festival, id: festival.id, variant: .light), .headquarter("another-festival")),
            (request(type: .district, id: district.id, variant: .light), .headquarter(festival.id)),
            (request(type: .district, id: district.id, variant: .light), .district("another-district")),
            (request(type: .festival, id: "missing-festival", variant: .light), .headquarter("missing-festival")),
            (request(type: .district, id: "missing-district", variant: .light), .district("missing-district")),
            (request(type: .store, id: "store-1", variant: .banner), .guest),
            (request(type: .festival, id: festival.id, variant: .banner), .headquarter(festival.id)),
            (request(type: .district, id: district.id, variant: .banner), .district(district.id)),
            (.init(target: .init(type: .festival, id: festival.id, variant: .light), contentType: "image/png"), .headquarter(festival.id))
        ]

        for (request, user) in cases {
            let images = ImageStorageClientSpy()
            await #expect(throws: Error.self) {
                try await withDependencies {
                    $0[FestivalRepositoryKey.self] = festivalRepository
                    $0[DistrictRepositoryKey.self] = districtRepository
                    $0[ImageStorageClientKey.self] = images
                } operation: {
                    try await ImageUploadUsecase().issue(request, user: user)
                }
            }
            #expect(await images.presignKeys.isEmpty)
        }
    }
}

private extension ImageUploadUsecaseTests {
    func request(
        type: ImageUploadTarget.Kind,
        id: String,
        variant: ImageUploadTarget.Variant
    ) -> ImageUploadURLRequest {
        .init(target: .init(type: type, id: id, variant: variant), contentType: "image/jpeg")
    }
}
