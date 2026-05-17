import SwiftUI
import StoreKit

/// Simple 3-tier StoreKit paywall.
struct PaywallView: View {
    @ObservedObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Choose your plan")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Basic is free. Upgrade for unlimited gestures and profiles.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    tierCard(
                        title: "Basic",
                        subtitle: "Free",
                        features: [
                            "Up to 3 gestures",
                            "No profile switching",
                            "Core clap/snap detection"
                        ],
                        actionTitle: "Current Plan",
                        action: {},
                        enabled: false,
                        accent: .gray
                    )

                    tierCard(
                        title: "Pro",
                        subtitle: proPriceLabel,
                        features: [
                            "Unlimited gestures",
                            "Up to 5 profiles",
                            "Shortcuts integration"
                        ],
                        actionTitle: proActionTitle,
                        action: purchasePro,
                        enabled: proProduct != nil && !isBusy,
                        accent: .blue
                    )

                    tierCard(
                        title: "Lifetime",
                        subtitle: lifetimePriceLabel,
                        features: [
                            "Unlimited everything",
                            "All future premium features",
                            "One-time purchase"
                        ],
                        actionTitle: lifetimeActionTitle,
                        action: purchaseLifetime,
                        enabled: lifetimeProduct != nil && !isBusy,
                        accent: .purple
                    )

                    Button("Restore Purchases", action: restore)
                        .disabled(isBusy)
                        .padding(.top, 8)

                    if case .failed(let error) = storeManager.purchaseStatus {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .navigationTitle("Upgrade")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var isBusy: Bool {
        switch storeManager.purchaseStatus {
        case .purchasing, .restoring: return true
        default: return false
        }
    }

    private var proProduct: Product? {
        storeManager.products.first(where: { $0.id.contains("monthly") })
            ?? storeManager.products.first(where: { $0.id.contains("yearly") })
    }

    private var lifetimeProduct: Product? {
        storeManager.products.first(where: { $0.id.contains("onetime") })
    }

    private var proPriceLabel: String {
        proProduct?.displayPrice ?? "$4.99/mo"
    }

    private var lifetimePriceLabel: String {
        lifetimeProduct?.displayPrice ?? "$19.99 once"
    }

    private var proActionTitle: String {
        isBusy ? "Processing..." : "Subscribe"
    }

    private var lifetimeActionTitle: String {
        isBusy ? "Processing..." : "Buy"
    }

    @ViewBuilder
    private func tierCard(
        title: String,
        subtitle: String,
        features: [String],
        actionTitle: String,
        action: @escaping () -> Void,
        enabled: Bool,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(accent)
                        Text(feature)
                            .font(.subheadline)
                    }
                }
            }

            Button(actionTitle, action: action)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(enabled ? accent : Color.gray)
                .foregroundStyle(.white)
                .cornerRadius(10)
                .disabled(!enabled)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(accent.opacity(0.3), lineWidth: 1)
        )
    }

    private func purchasePro() {
        guard let product = proProduct else { return }
        Task { await storeManager.purchase(product) }
    }

    private func purchaseLifetime() {
        guard let product = lifetimeProduct else { return }
        Task { await storeManager.purchase(product) }
    }

    private func restore() {
        Task { await storeManager.restorePurchases() }
    }
}

#Preview {
    PaywallView(storeManager: StoreManager())
}
