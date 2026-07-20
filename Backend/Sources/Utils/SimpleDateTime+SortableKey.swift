import Foundation
import Shared

extension SimpleDate {
    var sortableKey: String {
        "\(year)-\(String(format: "%02d", month))-\(String(format: "%02d", day))"
    }
}

extension SimpleTime {
    var sortableKey: String {
        "\(String(format: "%02d", hour))-\(String(format: "%02d", minute))"
    }
}
