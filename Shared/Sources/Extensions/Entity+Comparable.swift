//
//  Entity+Comparable.swift
//  matool-shared
//
//  Created by 松下和也 on 2026/01/27.
//

// MARK: - District
extension District: Comparable {
    public static func < (lhs: District, rhs: District) -> Bool {
        switch (lhs.group, rhs.group) {
        case let (l?, r?):
            let cmp = l.localizedStandardCompare(r)
            if cmp != .orderedSame {
                return cmp == .orderedAscending
            }
            return lhs.order < rhs.order
        case (nil, _?):
            return true
        case (_?, nil):
            return false
        case (nil, nil):
            return lhs.order < rhs.order
        }
    }
}

public extension Array where Element == District {
    func grouped() -> [String?: [District]] {
        Dictionary(grouping: self) { $0.group }
    }
    
    func prioritizing(districtId id: District.ID) -> [District] {
        guard let target = first(where: { $0.id == id }) else {
            return self.sorted() // 指定IDがなければソート済みで返す
        }
        
        let group = target.group
        
        let sameGroup = filter { $0.group == group && $0.id != id }.sorted()
        let others = filter { $0.group != group && $0.id != id }.sorted()
        
        return [target] + sameGroup + others
    }
    
    func prioritizing(group: String) -> [District] {
        let prioritized = filter { $0.group == group }.sorted()
        let others = filter { $0.group != group }.sorted()
        
        return prioritized + others
    }
}
