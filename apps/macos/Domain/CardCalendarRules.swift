import Foundation

/// Calendar-date contract v1. Device time zone is retained; the calendar is Gregorian on every locale.
public enum CardCalendarRules {
    public static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    public static func day(_ value: String?) -> Int? {
        guard let value else { return nil }
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...2).contains(text.count), text.utf8.allSatisfy({ (48...57).contains($0) }), let number = Int(text),
              (1...31).contains(number) else { return nil }
        return number
    }

    public static func monthDay(_ day: Int, from date: Date, offset: Int = 0) -> Date? {
        let cal = calendar
        guard (1...31).contains(day),
              let first = cal.date(from: cal.dateComponents([.year, .month], from: date)),
              let month = cal.date(byAdding: .month, value: offset, to: first),
              let range = cal.range(of: .day, in: .month, for: month) else { return nil }
        return cal.date(byAdding: .day, value: min(day, range.count) - 1, to: month)
    }

    public static func days(from: Date, to: Date) -> Int {
        let cal = calendar
        return cal.dateComponents([.day], from: cal.startOfDay(for: from), to: cal.startOfDay(for: to)).day ?? 0
    }

    public static func interestDays(bill: String?, due: String?, nextBill: Bool, today: Date) -> Int {
        guard let billDay = day(bill), let dueDay = day(due),
              let thisBill = monthDay(billDay, from: today) else { return -1 }
        let distance = days(from: today, to: thisBill)
        let next = distance < 0 || (distance == 0 && nextBill)
        guard let billDate = monthDay(billDay, from: today, offset: next ? 1 : 0),
              let dueDate = monthDay(dueDay, from: billDate, offset: dueDay <= billDay ? 1 : 0) else { return -1 }
        return max(0, days(from: today, to: dueDate))
    }

    public static func nextDue(bill: String?, due: String?, today: Date) -> Date? {
        guard day(bill) != nil, let dueDay = day(due), let current = monthDay(dueDay, from: today) else { return nil }
        // Include this month's repayment of a previous month's statement.
        return days(from: today, to: current) >= 0 ? current : monthDay(dueDay, from: today, offset: 1)
    }

    public static func expiryMonth(_ value: String?) -> Int? {
        let text = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let slash = text.split(separator: "/", omittingEmptySubsequences: false)
        var year: Int, month: Int
        if slash.count == 2, (1...2).contains(slash[0].count), [2, 4].contains(slash[1].count),
           let m = Int(slash[0]), let y = Int(slash[1]) {
            month = m; year = slash[1].count == 2 ? 2000 + y : y
        } else {
            let parts = text.split(separator: "-", omittingEmptySubsequences: false)
            guard (parts.count == 2 || parts.count == 3), parts[0].count == 4,
                  let y = Int(parts[0]), let m = Int(parts[1]) else { return nil }
            year = y; month = m
            if parts.count == 3 {
                guard let d = Int(parts[2]), (1...31).contains(d),
                      let date = calendar.date(from: DateComponents(year: y, month: m, day: d)),
                      calendar.component(.month, from: date) == m else { return nil }
            }
        }
        guard (1...12).contains(month), (100...9999).contains(year) else { return nil }
        return year * 12 + month - 1
    }

    public static func monthIndex(_ date: Date) -> Int {
        calendar.component(.year, from: date) * 12 + calendar.component(.month, from: date) - 1
    }
}
