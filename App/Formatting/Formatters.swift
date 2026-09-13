import Foundation

enum Formatters {
    static func entries(_ count: Int) -> String {
        count == 1 ? "1 entry" : "\(count) entries"
    }

    static func issues(_ count: Int) -> String {
        count == 1 ? "1 issue" : "\(count) issues"
    }

    static func lines(_ count: Int) -> String {
        count == 1 ? "1 line" : "\(count) lines"
    }
}
