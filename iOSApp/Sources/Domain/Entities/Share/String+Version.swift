extension String {
    func isVersion(greaterThanOrEqualTo other: String) -> Bool {
        let components1 = split(separator: ".").compactMap { Int($0) }
        let components2 = other.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(components1.count, components2.count) {
            let v1 = i < components1.count ? components1[i] : 0
            let v2 = i < components2.count ? components2[i] : 0
            if v1 > v2 { return true }
            if v1 < v2 { return false }
        }
        return true
    }
}
