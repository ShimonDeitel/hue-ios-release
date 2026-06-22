import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @AppStorage("quickmath.theme") private var themeRaw = AppTheme.system.rawValue
    @State private var showDeleteConfirm = false
    @State private var showPaywall = false

    private var theme: AppTheme {
        get { AppTheme(rawValue: themeRaw) ?? .system }
        set { themeRaw = newValue.rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                List {
                    // Pro
                    Section("Subscription") {
                        if store.isPro {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Color.qmAccent)
                                Text("Hue Pro — Active")
                                    .font(.subheadline.weight(.semibold))
                            }
                            Button("Manage Subscription") {
                                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .foregroundStyle(Color.qmAccent)
                        } else {
                            Button("Unlock Hue Pro — \(store.displayPrice)/mo") {
                                showPaywall = true
                            }
                            .foregroundStyle(Color.qmAccent)
                            Button("Restore Purchases") {
                                Task { await store.restore() }
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    // Appearance
                    Section("Appearance") {
                        Picker("Theme", selection: Binding(
                            get: { AppTheme(rawValue: themeRaw) ?? .system },
                            set: { themeRaw = $0.rawValue }
                        )) {
                            ForEach(AppTheme.allCases) { t in
                                Text(t.label).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Links
                    Section("Legal") {
                        Link("Privacy Policy", destination: URL(string: "https://shimondeitel.github.io/hue-site/privacy.html")!)
                            .foregroundStyle(Color.qmAccent)
                        Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            .foregroundStyle(Color.qmAccent)
                    }

                    // Data
                    Section("Data") {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete All Data", systemImage: "trash")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete All Data",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    Haptics.warning()
                    appModel.deleteAllData()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All mood entries will be permanently removed. This cannot be undone.")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(store)
            }
        }
    }
}
