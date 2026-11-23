import Foundation

/// What day it is, as far as the board is concerned. Everything on the board that depends on the date (which month it
/// shows, which day is "today", what a day is called) asks here.
///
/// To see the app on another day while building, launch with `-today 2026-12-05` (debug builds only).
enum BoardCalendar {
    static var now: Date { override ?? Date() }

    private static let override: Date? = {
        #if DEBUG
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-today"), i + 1 < args.count {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd HH:mm"
            f.locale = Locale(identifier: "en_US_POSIX")
            return f.date(from: args[i + 1] + " 12:00")
        }
        #endif
        return nil
    }()

    private static let cal = Calendar.current
    private static let weekdayNames = ["Sun", "Mon", "Tues", "Wed", "Thu", "Fri", "Sat"]

    /// Day of the month, 1 to 31.
    static var today: Int { cal.component(.day, from: now) }
    static var monthNumber: Int { cal.component(.month, from: now) }
    static var year: Int { cal.component(.year, from: now) }

    /// "2026-12": the key a month's posts are saved under.
    static var monthKey: String { String(format: "%04d-%02d", year, monthNumber) }

    /// "December" and "Dec".
    static var monthName: String { format("MMMM", now) }
    static var monthShort: String { format("MMM", now) }

    /// A moment on a day of this month.
    static func date(day: Int, hour: Int, minute: Int) -> Date {
        cal.date(from: DateComponents(year: year, month: monthNumber, day: day, hour: hour, minute: minute)) ?? now
    }

    /// "Mon", for a day of this month.
    static func weekday(of day: Int) -> String {
        weekdayNames[cal.component(.weekday, from: date(day: day, hour: 12, minute: 0)) - 1]
    }

    /// The first day of a month given as "2026-11".
    static func date(forKey key: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: key) ?? now
    }
    /// "November", for "2026-11".
    static func monthName(forKey key: String) -> String { format("MMMM", date(forKey: key)) }

    static func format(_ pattern: String, _ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = pattern
        return f.string(from: date)
    }
}
