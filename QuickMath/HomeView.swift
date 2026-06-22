import SwiftUI
import SwiftData

struct HomeView: View {
    var forceScreen: String? = nil

    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var showInsights = false
    @State private var showNoteSheet = false
    @State private var pendingNote: String = ""
    @State private var pendingColor: String? = nil

    // Use Classic palette always for the free tier; allow Pro palettes later
    private var activePalette: ColorPalette {
        appModel.palettes.first(where: { !$0.isPro }) ?? DefaultPalettes.free
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                ScrollView {
                    VStack(spacing: 28) {
                        // Header metrics
                        HStack(spacing: 12) {
                            MetricTile(value: "\(appModel.streak)", label: "Day Streak")
                            MetricTile(value: "\(appModel.allEntries.count)", label: "Total Days")
                        }
                        .padding(.horizontal)

                        // Today's tile
                        todayCard

                        // This month mini grid
                        monthGridSection

                        // Pro insight tile
                        proInsightTile
                    }
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Hue")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Haptics.tap()
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Color.qmAccent)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(appModel)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showInsights) {
                InsightsView()
                    .environmentObject(appModel)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showNoteSheet) {
                noteSheet
            }
        }
        .onAppear {
            if forceScreen == "insights" { showInsights = true }
            if forceScreen == "paywall" { showPaywall = true }
        }
    }

    // MARK: - Today Card

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How do you feel today?")
                .font(.headline)
                .foregroundStyle(.primary)

            if let entry = appModel.todayEntry {
                // Already logged
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(hex: entry.colorHex))
                        .frame(width: 48, height: 48)
                        .shadow(color: Color(hex: entry.colorHex).opacity(0.3), radius: 8, x: 0, y: 4)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Logged")
                            .font(.subheadline.weight(.semibold))
                        if let note = entry.note, !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        } else {
                            Text("Tap a color to change")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    // Add/edit note
                    Button {
                        pendingNote = entry.note ?? ""
                        pendingColor = entry.colorHex
                        showNoteSheet = true
                    } label: {
                        Image(systemName: "pencil.circle")
                            .font(.title2)
                            .foregroundStyle(Color.qmAccent)
                    }
                }
            } else {
                Text("Tap a color swatch to log your mood.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Color swatches
            colorSwatches
        }
        .qmCard()
        .padding(.horizontal)
    }

    private var colorSwatches: some View {
        let hexes = activePalette.colorHexes
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
            ForEach(hexes, id: \.self) { hex in
                Button {
                    Haptics.tap()
                    appModel.logMood(colorHex: hex)
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    appModel.todayEntry?.colorHex == hex ? Color.primary : Color.clear,
                                    lineWidth: 3
                                )
                        )
                        .shadow(color: Color(hex: hex).opacity(0.25), radius: 4, x: 0, y: 2)
                }
            }
        }
    }

    // MARK: - Month Grid

    private var monthGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let cal = Calendar.current
            let now = Date.now
            let year = cal.yearOf(now)
            let month = cal.monthOf(now)
            let entries = appModel.entriesForMonth(year: year, month: month)
            let monthName = now.formatted(.dateTime.month(.wide).year())

            HStack {
                Text(monthName)
                    .font(.headline)
                Spacer()
            }

            GridView(year: year, month: month, entries: entries)
        }
        .qmCard()
        .padding(.horizontal)
    }

    // MARK: - Pro Insight Tile

    private var proInsightTile: some View {
        Button {
            Haptics.tap()
            if store.isPro {
                showInsights = true
            } else {
                showPaywall = true
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: store.isPro ? "chart.bar.fill" : "lock.fill")
                    .font(.title2)
                    .foregroundStyle(Color.qmAccent)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.isPro ? "Your Color History" : "Hue Pro")
                        .font(.subheadline.weight(.semibold))
                    Text(store.isPro ? "Multi-year mosaic & weekly insights" : "Mosaic, palettes & insights — $0.99/mo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .qmCard()
        .padding(.horizontal)
    }

    // MARK: - Note Sheet

    private var noteSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TextEditor(text: $pendingNote)
                    .frame(minHeight: 120)
                    .padding(12)
                    .background(Color.qmCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal)
                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Add a note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showNoteSheet = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let color = pendingColor {
                            appModel.logMood(colorHex: color, note: pendingNote.isEmpty ? nil : pendingNote)
                        }
                        showNoteSheet = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
