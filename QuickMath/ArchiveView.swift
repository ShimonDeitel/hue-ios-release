import SwiftUI

/// Pro feature: multi-year color mosaic, palette browser, and weekly insights.
struct InsightsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var selectedYear: Int = Calendar.current.component(.year, from: .now)

    private var years: [Int] {
        let ys = appModel.yearsWithEntries
        let current = Calendar.current.component(.year, from: .now)
        if ys.contains(current) { return ys }
        return (ys + [current]).sorted()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                ScrollView {
                    VStack(spacing: 24) {
                        // Year picker
                        if years.count > 1 {
                            Picker("Year", selection: $selectedYear) {
                                ForEach(years, id: \.self) { y in
                                    Text(String(y)).tag(y)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                        }

                        // Year mosaic
                        mosaicSection

                        // Weekly insights
                        insightsSection

                        // Palette browser
                        palettesSection
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Your Colors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Mosaic

    private var mosaicSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Year in Color — \(String(selectedYear))")
                .font(.headline)
                .padding(.horizontal)

            let entryMap = appModel.entriesForYear(selectedYear)
            YearMosaicView(year: selectedYear, entryMap: entryMap)
                .padding(.horizontal, 8)

            let count = appModel.allEntries.filter {
                Calendar.current.component(.year, from: $0.date) == selectedYear
            }.count
            Text("\(count) of \(daysInYear(selectedYear)) days logged")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .qmCard()
        .padding(.horizontal)
    }

    // MARK: - Weekly insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This Week")
                .font(.headline)

            let weekEntries = lastSevenDaysEntries()
            if weekEntries.isEmpty {
                Text("Log your mood daily to see patterns.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                // Weekly color strip
                HStack(spacing: 6) {
                    ForEach(lastSevenDates(), id: \.self) { date in
                        let entry = weekEntries.first { Calendar.current.isSameDay($0.date, date) }
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(entry.map { Color(hex: $0.colorHex) } ?? Color(uiColor: .tertiarySystemFill))
                                .frame(height: 48)
                            Text(dayAbbrev(date))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                // Most frequent color
                if let dominantHex = dominantColor(weekEntries) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(hex: dominantHex))
                            .frame(width: 32, height: 32)
                        Text("Your most-logged mood color this week")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .qmCard()
        .padding(.horizontal)
    }

    // MARK: - Palettes

    private var palettesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Palettes")
                .font(.headline)

            ForEach(appModel.palettes, id: \.id) { palette in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(palette.name)
                            .font(.subheadline.weight(.medium))
                        if palette.isPro {
                            Text("Pro")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.qmAccent, in: Capsule())
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach(palette.colorHexes, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 28, height: 28)
                        }
                    }
                }
            }
        }
        .qmCard()
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func daysInYear(_ year: Int) -> Int {
        let cal = Calendar.current
        guard let firstDay = cal.date(from: DateComponents(year: year, month: 1, day: 1)) else { return 365 }
        return cal.range(of: .day, in: .year, for: firstDay)?.count ?? 365
    }

    private func lastSevenDates() -> [Date] {
        let cal = Calendar.current
        return (0..<7).compactMap { cal.date(byAdding: .day, value: -6 + $0, to: cal.startOfDay(for: .now)) }
    }

    private func lastSevenDaysEntries() -> [MoodDay] {
        let dates = lastSevenDates()
        guard let start = dates.first, let end = dates.last else { return [] }
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: end) ?? end
        return appModel.allEntries.filter { $0.date >= start && $0.date <= endOfDay }
    }

    private func dominantColor(_ entries: [MoodDay]) -> String? {
        let freq = Dictionary(grouping: entries, by: { $0.colorHex }).mapValues { $0.count }
        return freq.max(by: { $0.value < $1.value })?.key
    }

    private func dayAbbrev(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "E"
        return String(fmt.string(from: date).prefix(1))
    }
}
