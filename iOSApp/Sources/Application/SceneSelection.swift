import Shared

enum FestivalSelectionResult: Equatable, Sendable {
    case unchanged
    case changed(UserRole)
}

struct SceneSelection: Equatable, Sendable {
    let festivalId: Festival.ID?
    let districtId: District.ID?

    init(festivalId: Festival.ID?, districtId: District.ID?) {
        self.festivalId = festivalId
        self.districtId = districtId
    }
}
