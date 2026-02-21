import Foundation

extension Status {
    var text: String {
        switch self {
        case .update(let location):
            return "\(location.timestamp.text(of: "HH:mm:ss")) 送信成功"
        case .loading(let date):
            return "\(date.text(of: "HH:mm:ss")) 読み込み中"
        case .locationError(let date):
            return "\(date.text(of: "HH:mm:ss")) 取得失敗"
        case .apiError(let date, let error):
            return "\(date.text(of: "HH:mm:ss")) 送信失敗 \(error.localizedDescription)"
        case .delete(let date):
            return "\(date.text(of: "HH:mm:ss")) 削除済み"
        }
    }
}
