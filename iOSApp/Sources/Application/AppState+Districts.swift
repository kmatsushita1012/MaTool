import Shared

extension AppState {
    func district(id: District.ID) -> District? {
        festivalState.districts.first { $0.id == id }
    }

    var selectedDistrict: District? {
        guard let districtState else { return nil }
        return district(id: districtState.districtId)
    }

    func floatLocation(for districtId: District.ID) -> FloatLocation? {
        festivalState.floatLocations.first { $0.districtId == districtId }
    }
}
