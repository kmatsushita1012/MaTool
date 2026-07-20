import Foundation

extension Date {
    func text(year: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = year ? "yyyy/MM/dd HH:mm:ss" : "MM/dd HH:mm:ss"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: self)
    }

    func text(of format: String = "yyyy/MM/dd HH:mm:ss") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: self)
    }
}
