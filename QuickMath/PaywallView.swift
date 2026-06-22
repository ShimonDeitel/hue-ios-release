import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    private let benefits: [String] = [
        "Full multi-year color mosaic with zoomable history",
        "Extra seasonal & custom palettes refreshed monthly",
        "Daily reminder plus weekly color-pattern insights"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                ScrollView {
                    VStack(spacing: 32) {
                        // Icon + title
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(uiColor: .secondarySystemBackground))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color.qmAccent)
                            }
                            Text("Hue Pro")
                                .font(.title.weight(.bold))
                            Text("$0.99 / month. Auto-renews until you cancel.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)

                        // Benefits
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(benefits, id: \.self) { benefit in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.qmAccent)
                                        .font(.body)
                                        .frame(width: 24)
                                    Text(benefit)
                                        .font(.body)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .qmCard()
                        .padding(.horizontal)

                        // Purchase button
                        VStack(spacing: 12) {
                            Button {
                                Haptics.tap()
                                Task { await store.purchase() }
                            } label: {
                                if store.purchaseInFlight {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                        .frame(maxWidth: .infinity)
                                } else {
                                    Text("Unlock for \(store.displayPrice)/month")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .prominentButton()
                            .padding(.horizontal)
                            .disabled(store.purchaseInFlight)

                            Button("Restore Purchases") {
                                Task { await store.restore() }
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color.qmAccent)

                            Button {
                                if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text("Manage Subscription")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Auto-renew disclosure
                        VStack(spacing: 8) {
                            Text("Payment will be charged to your Apple ID account at the confirmation of purchase. Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions by going to your account settings on the App Store after purchase.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            HStack(spacing: 16) {
                                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                Link("Privacy Policy", destination: URL(string: "https://shimondeitel.github.io/hue-site/privacy.html")!)
                            }
                            .font(.caption)
                            .foregroundStyle(Color.qmAccent)
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Hue Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: store.isPro) { _, newValue in
                if newValue { dismiss() }
            }
        }
    }
}
