import Foundation

// MARK: - Luna's Age Calculator

enum LunaAge {

    /// Luna's birthday: 2 juli 2023
    static let birthday: Date = {
        var c = DateComponents()
        c.year = 2023; c.month = 7; c.day = 2
        return Calendar.current.date(from: c)!
    }()

    // MARK: - Full age string (for detail views)
    // "Luna var 1 år och 3 månader gammal"

    static func ageLabel(at date: Date) -> String {
        "Luna var \(age(at: date)) gammal"
    }

    static func age(at date: Date) -> String {
        guard date > birthday else { return "inte född än" }
        let cal   = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: birthday, to: date)
        let y = comps.year  ?? 0
        let m = comps.month ?? 0
        let d = comps.day   ?? 0

        var parts: [String] = []
        if y > 0 { parts.append("\(y) \(y == 1 ? "år" : "år")") }
        if m > 0 { parts.append("\(m) \(m == 1 ? "månad" : "månader")") }
        if d > 0 && y == 0 { parts.append("\(d) \(d == 1 ? "dag" : "dagar")") }

        switch parts.count {
        case 0:  return "precis född"
        case 1:  return parts[0]
        case 2:  return "\(parts[0]) och \(parts[1])"
        default: return "\(parts[0]), \(parts[1]) och \(parts[2])"
        }
    }

    // MARK: - Short form (for cards)
    // "1 år 3 mån"

    static func ageShort(at date: Date) -> String {
        guard date > birthday else { return "−" }
        let cal   = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: birthday, to: date)
        let y = comps.year  ?? 0
        let m = comps.month ?? 0
        let d = comps.day   ?? 0

        if y > 0 && m > 0 { return "\(y) år \(m) mån" }
        if y > 0           { return "\(y) år" }
        if m > 0 && d > 0  { return "\(m) mån \(d) d" }
        if m > 0           { return "\(m) mån" }
        return "\(d) d"
    }

    // MARK: - Formatted date in Swedish

    static func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale    = Locale(identifier: "sv_SE")
        f.dateStyle = .long
        f.timeStyle = .none
        return f.string(from: date)
    }
}
