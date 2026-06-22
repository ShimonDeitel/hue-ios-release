import SwiftUI

/// The primary color-grid for a single month. Each cell is one day of the month,
/// colored by the mood logged that day (or empty/grey if none).
struct GridView: View {
    let year: Int
    let month: Int
    let entries: [MoodDay]

    private let cal = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    /// Weekday symbol headers: Sun … Sat
    private let weekdaySymbols: [String] = {
        let cal = Calendar.current
        return cal.veryShortWeekdaySymbols
    }()

    /// All days to display: leading grey cells + actual days
    private var cells: [GridCell] {
        var comps = DateComponents(year: year, month: month, day: 1)
        guard let firstDay = cal.date(from: comps) else { return [] }
        let firstWeekday = cal.component(.weekday, from: firstDay) // 1 = Sunday
        let leadingBlanks = firstWeekday - 1

        let range = cal.range(of: .day, in: .month, for: firstDay)!
        let dayCount = range.count

        var result: [GridCell] = []
        // Blanks
        for _ in 0..<leadingBlanks {
            result.append(GridCell(day: nil, colorHex: nil))
        }
        // Actual days
        for day in 1...dayCount {
            comps.day = day
            let date = cal.date(from: comps)!
            let hex = entries.first { cal.isSameDay($0.date, date) }?.colorHex
            result.append(GridCell(day: day, colorHex: hex))
        }
        return result
    }

    var body: some View {
        VStack(spacing: 6) {
            // Weekday headers
            HStack(spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { sym in
                    Text(sym)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            let todayDay = Calendar.current.component(.day, from: .now)
            let todayMonth = Calendar.current.component(.month, from: .now)
            let todayYear = Calendar.current.component(.year, from: .now)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(cells.indices, id: \.self) { i in
                    let cell = cells[i]
                    if let day = cell.day {
                        let today = day == todayDay && month == todayMonth && year == todayYear
                        DayCell(day: day, colorHex: cell.colorHex, isToday: today)
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
    }
}

private struct GridCell {
    let day: Int?
    let colorHex: String?
}

private struct DayCell: View {
    let day: Int
    let colorHex: String?
    var isToday: Bool = false

    var body: some View {
        ZStack {
            if let hex = colorHex {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(hex: hex))
            } else {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemFill))
            }
            Text("\(day)")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(colorHex != nil ? .white : Color(.tertiaryLabel))
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(Color.qmAccent.opacity(isToday ? 0.8 : 0), lineWidth: 1.5)
        )
    }
}

// MARK: - Year Mosaic (Pro)

/// Full-year color mosaic view for the Insights screen.
struct YearMosaicView: View {
    let year: Int
    let entryMap: [Date: MoodDay]

    private let cal = Calendar.current
    private let cellSize: CGFloat = 10
    private let spacing: CGFloat = 2

    private var monthsData: [(month: Int, days: [DayData])] {
        (1...12).map { month in
            var comps = DateComponents(year: year, month: month, day: 1)
            guard let first = cal.date(from: comps) else { return (month, []) }
            let count = cal.range(of: .day, in: .month, for: first)?.count ?? 30
            var days: [DayData] = []
            for d in 1...count {
                comps.day = d
                if let date = cal.date(from: comps) {
                    let key = cal.startOfDay(for: date)
                    days.append(DayData(date: date, colorHex: entryMap[key]?.colorHex))
                }
            }
            return (month, days)
        }
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: 13), spacing: spacing) {
            ForEach(monthsData, id: \.month) { monthData in
                VStack(spacing: spacing) {
                    Text(monthAbbrev(monthData.month))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.secondary)

                    ForEach(monthData.days.indices, id: \.self) { i in
                        let d = monthData.days[i]
                        RoundedRectangle(cornerRadius: 2)
                            .fill(d.colorHex.map { Color(hex: $0) } ?? Color(uiColor: .tertiarySystemFill))
                            .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func monthAbbrev(_ m: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        var comps = DateComponents(year: year, month: m, day: 1)
        let date = Calendar.current.date(from: comps) ?? .now
        return String(formatter.string(from: date).prefix(1))
    }
}

private struct DayData {
    let date: Date
    let colorHex: String?
}
