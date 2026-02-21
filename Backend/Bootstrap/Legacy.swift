//
//  Legacy.swift
//  matool-backend
//
//  Created by 松下和也 on 2026/02/20.
//
import Shared
import Foundation

enum Legacy {
    // Festivalに改名 対応済
    // TableName: matool-regions
    struct Region: Codable, Equatable, Identifiable, Hashable {
        let id: String
        var name: String
        var subname: String
        @NullEncodable var description: String?
        var prefecture: String
        var city: String
        var base: Coordinate
        var spans: [Span] = [] // 削除して正規化
        var milestones: [Information] = [] // Checkpointに移行
        @NullEncodable var imagePath:String?
    }
    
    // 廃止　Periodに移行
    struct Span: Codable, Identifiable, Hashable, Equatable{
        let id: String
        let start: Date
        let end: Date
    }
    
    // Checkpointに改名
    struct Information: Codable, Equatable, Hashable, Identifiable{
        let id: String
        var name: String = ""
        @NullEncodable var description: String? = nil
    }
    
    
    // TableName: matool-districts
    struct District: Codable, Equatable, Identifiable{
        let id: String
        var name: String
        let regionId: String // festivalIdに改名
        @NullEncodable var description: String? = nil
        @NullEncodable var base: Coordinate? = nil
        var area: [Coordinate] = []
        @NullEncodable var imagePath:String? = nil
        var performances: [Performance] = [] // 削除して正規化
        var visibility: Visibility
    }
    
    struct Performance: Codable, Equatable, Identifiable {
        let id: String
        var name: String = ""
        var performer: String = ""
        @NullEncodable var description: String?
    }
    
    // TableName: matool-routes
    struct Route: Codable, Equatable, Identifiable {
        let id: String
        let districtId: String
        var date: SimpleDate = .today // periodIdに移行 空欄にしておく（後で対処）
        var title: String = ""
        @NullEncodable var description: String?
        var points: [Point] = [] //削除して正規化
        var start: SimpleTime // Pointの先頭に移行
        var goal: SimpleTime // Pointの末尾に移行
    }
    
    // 削除
    struct Segment: Codable, Equatable {
        let id: String
        let start: Coordinate
        let end: Coordinate
        var coordinates: [Coordinate]
        let isPassed: Bool
        init(id: String,start: Coordinate, end: Coordinate, coordinates: [Coordinate]? = nil, isPassed: Bool = false) {
            self.id = id
            self.start = start
            self.end = end
            self.coordinates = coordinates ?? [start, end]
            self.isPassed = isPassed
        }
    }
    
    // 正規化済み　順番とtitleを元に仕分けてShared.Pointに移行
    // - 先頭 Anchor.startとRoute.start->time
    // - 末尾　Anchor.endとRoute.goal->time
    // - "休憩" Anchor.restとPoint.time
    // - "<Information.nameに完全一致>"　Information.id -> checkpointId, Point.time
    // - "nil" Anchor.none
    // - "<Performance.nameに完全一致>" Performance.id -> performanceId,Point.time
    
    struct Point: Codable, Identifiable, Equatable, Hashable{
        let id: String
        var coordinate: Coordinate
        @NullEncodable var title: String? = nil
        @NullEncodable var description: String? = nil
        @NullEncodable var time: SimpleTime? = nil
        var isPassed: Bool = false
        var shouldExport: Bool = false
        
        init(id:String, coordinate: Coordinate, title: String?=nil, description: String?=nil, time: SimpleTime?=nil, isPassed: Bool = false, shouldExport: Bool = false) {
            self.id = id
            self.coordinate = coordinate
            self.title = title
            self.description = description
            self.time = time
            self.isPassed = isPassed
            self.shouldExport = shouldExport
        }
    }
    
    enum Visibility: String, Codable, Hashable, CaseIterable {
        case admin
        case route
        case all
    }
}
