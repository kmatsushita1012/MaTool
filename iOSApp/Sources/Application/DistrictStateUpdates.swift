import Shared

func replaceDistrict(_ district: District, in districts: inout [District]) {
    guard let index = districts.firstIndex(where: { $0.id == district.id }) else { return }
    districts[index] = district
}

func upsertDistrict(_ district: District, in districts: inout [District]) {
    if let index = districts.firstIndex(where: { $0.id == district.id }) {
        districts[index] = district
    } else {
        districts.append(district)
    }
}
