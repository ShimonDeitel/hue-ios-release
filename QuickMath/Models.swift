import Foundation
import SwiftData

// MARK: - SwiftData Models

/// A single daily mood entry: one color hex + optional note and energy level.
@Model
final class MoodDay {
    var id: UUID = UUID()
    var date: Date = Date.now
    var colorHex: String = "#007AFF"
    var note: String? = nil
    var energy: Int? = nil

    init(id: UUID = UUID(), date: Date = .now, colorHex: String, note: String? = nil, energy: Int? = nil) {
        self.id = id
        self.date = date
        self.colorHex = colorHex
        self.note = note
        self.energy = energy
    }
}

/// A named color palette (default or Pro-only seasonal/custom).
@Model
final class ColorPalette {
    var id: UUID = UUID()
    var name: String = ""
    var colorHexes: [String] = []
    var isPro: Bool = false

    init(id: UUID = UUID(), name: String, colorHexes: [String], isPro: Bool = false) {
        self.id = id
        self.name = name
        self.colorHexes = colorHexes
        self.isPro = isPro
    }
}

// MARK: - Default Palettes

enum DefaultPalettes {
    static let free = ColorPalette(
        name: "Classic",
        colorHexes: ["#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#007AFF", "#AF52DE"],
        isPro: false
    )
    static let autumn = ColorPalette(
        name: "Autumn",
        colorHexes: ["#FF6B35", "#F7931E", "#C0392B", "#8B4513", "#D4A017", "#6B4226"],
        isPro: true
    )
    static let ocean = ColorPalette(
        name: "Ocean",
        colorHexes: ["#0077B6", "#00B4D8", "#90E0EF", "#023E8A", "#48CAE4", "#ADE8F4"],
        isPro: true
    )
    static let forest = ColorPalette(
        name: "Forest",
        colorHexes: ["#1B4332", "#2D6A4F", "#40916C", "#52B788", "#74C69D", "#B7E4C7"],
        isPro: true
    )
    static let dusk = ColorPalette(
        name: "Dusk",
        colorHexes: ["#6A0572", "#AB83A1", "#E8B4CB", "#F7C3D0", "#D4A5A5", "#9C6B9E"],
        isPro: true
    )

    static var all: [ColorPalette] { [free, autumn, ocean, forest, dusk] }
}

// MARK: - Calendar helpers

extension Calendar {
    /// Midnight at the start of a given date.
    func startOfDayDate(_ date: Date) -> Date {
        startOfDay(for: date)
    }

    /// All dates in the given year.
    func datesInYear(_ year: Int) -> [Date] {
        var comps = DateComponents(year: year, month: 1, day: 1)
        guard let start = self.date(from: comps) else { return [] }
        var result: [Date] = []
        comps = DateComponents(year: year, month: 12, day: 31)
        guard let end = self.date(from: comps) else { return [] }
        var current = start
        while current <= end {
            result.append(current)
            current = date(byAdding: .day, value: 1, to: current) ?? current
        }
        return result
    }

    func isSameDay(_ a: Date, _ b: Date) -> Bool {
        isDate(a, inSameDayAs: b)
    }

    func yearOf(_ date: Date) -> Int {
        component(.year, from: date)
    }

    func monthOf(_ date: Date) -> Int {
        component(.month, from: date)
    }
}

// MARK: - AppModel

@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    weak var store: Store?

    @Published private(set) var allEntries: [MoodDay] = []
    @Published private(set) var streak: Int = 0
    @Published private(set) var todayEntry: MoodDay? = nil
    @Published private(set) var palettes: [ColorPalette] = []

    init(container: ModelContainer) {
        self.container = container
        reload()
    }

    static func makeContainer() -> ModelContainer {
        let schema = Schema([MoodDay.self, ColorPalette.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return (try? ModelContainer(for: schema, configurations: [fallback]))!
        }
    }

    func reload() {
        let ctx = container.mainContext
        let entryDesc = FetchDescriptor<MoodDay>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let paletteDesc = FetchDescriptor<ColorPalette>()
        allEntries = (try? ctx.fetch(entryDesc)) ?? []
        palettes = (try? ctx.fetch(paletteDesc)) ?? []

        // Seed default palettes if missing
        if palettes.isEmpty {
            for p in DefaultPalettes.all {
                ctx.insert(p)
            }
            try? ctx.save()
            palettes = (try? ctx.fetch(paletteDesc)) ?? []
        }

        // Compute today entry
        let cal = Calendar.current
        todayEntry = allEntries.first { cal.isSameDay($0.date, .now) }

        // Compute streak
        streak = computeStreak()
    }

    func refresh() { reload() }

    // MARK: - Entry management

    /// Save or update today's mood entry with the given color hex.
    func logMood(colorHex: String, note: String? = nil, energy: Int? = nil) {
        let ctx = container.mainContext
        let cal = Calendar.current
        if let existing = allEntries.first(where: { cal.isSameDay($0.date, .now) }) {
            existing.colorHex = colorHex
            if let n = note { existing.note = n }
            if let e = energy { existing.energy = e }
        } else {
            let entry = MoodDay(date: .now, colorHex: colorHex, note: note, energy: energy)
            ctx.insert(entry)
        }
        try? ctx.save()
        reload()
    }

    /// All entries for a given month, keyed by calendar day.
    func entriesForMonth(year: Int, month: Int) -> [MoodDay] {
        let cal = Calendar.current
        return allEntries.filter {
            cal.component(.year, from: $0.date) == year &&
            cal.component(.month, from: $0.date) == month
        }
    }

    /// All entries for a given year, keyed by day-of-year.
    func entriesForYear(_ year: Int) -> [Date: MoodDay] {
        let cal = Calendar.current
        var dict: [Date: MoodDay] = [:]
        for entry in allEntries {
            if cal.component(.year, from: entry.date) == year {
                let day = cal.startOfDay(for: entry.date)
                dict[day] = entry
            }
        }
        return dict
    }

    /// Years that have at least one entry.
    var yearsWithEntries: [Int] {
        let cal = Calendar.current
        let years = Set(allEntries.map { cal.component(.year, from: $0.date) })
        return Array(years).sorted()
    }

    func deleteAllData() {
        let ctx = container.mainContext
        for entry in allEntries { ctx.delete(entry) }
        try? ctx.save()
        reload()
    }

    // MARK: - Streak

    private func computeStreak() -> Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = cal.startOfDay(for: .now)
        // If today has no entry yet, still allow checking back from yesterday
        let hasTodayEntry = allEntries.contains { cal.isSameDay($0.date, checkDate) }
        if !hasTodayEntry {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }
        while true {
            if allEntries.contains(where: { cal.isSameDay($0.date, checkDate) }) {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        return streak
    }
}
