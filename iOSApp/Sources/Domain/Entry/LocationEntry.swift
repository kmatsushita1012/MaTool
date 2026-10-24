import Shared

struct FloatEntry: Entity, Identifiable {
    let floatLocation: FloatLocation
    let district: District

    var id: FloatLocation.ID { floatLocation.id }
}
