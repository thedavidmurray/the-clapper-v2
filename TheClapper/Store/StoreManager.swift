import Foundation
import StoreKit

/// Manages freemium purchases and feature gating
@MainActor
class StoreManager: ObservableObject {
    @Published var isPremium = false
    @Published var products: [Product] = []
    @Published var purchaseStatus: PurchaseStatus = .idle
    @Published var subscriptionStatus: SubscriptionStatus = .notSubscribed
    
    enum PurchaseStatus {
        case idle
        case purchasing
        case restoring
        case succeeded
        case failed(Error)
    }
    
    enum SubscriptionStatus {
        case notSubscribed
        case subscribed(expirationDate: Date)
        case expired
    }
    
    // Product IDs
    private let productIds = [
        "theclapper.premium.onetime",
        "theclapper.premium.monthly",
        "theclapper.premium.yearly"
    ]
    
    private var updates: Task<Void, Never>?
    
    init() {
        Task {
            await loadProducts()
            await updatePremiumStatus()
            listenForTransactions()
        }
    }
    
    deinit {
        updates?.cancel()
    }
    
    // MARK: - Products
    
    /// Load available products from App Store
    func loadProducts() async {
        do {
            products = try await Product.products(for: productIds)
            print("Loaded \(products.count) products")
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    /// Purchase a product
    func purchase(_ product: Product) async {
        purchaseStatus = .purchasing
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                await handleSuccessfulPurchase(verification)
                purchaseStatus = .succeeded
            case .userCancelled:
                purchaseStatus = .idle
            case .pending:
                purchaseStatus = .idle
            @unknown default:
                purchaseStatus = .idle
            }
        } catch {
            purchaseStatus = .failed(error)
        }
    }
    
    /// Restore previous purchases
    func restorePurchases() async {
        purchaseStatus = .restoring
        
        do {
            try await AppStore.sync()
            await updatePremiumStatus()
            purchaseStatus = .succeeded
        } catch {
            purchaseStatus = .failed(error)
        }
    }
    
    // MARK: - Premium Status
    
    /// Check if user has premium access
    private func updatePremiumStatus() async {
        var hasPremium = false
        
        for product in products {
            switch product.type {
            case .nonConsumable:
                // Check if purchased
                let result = await product.currentEntitlement
                if case .verified(_) = result {
                    hasPremium = true
                }
                
            case .autoRenewable:
                // Check subscription status via current entitlement
                let result = await product.currentEntitlement
                if case .verified(let transaction) = result {
                    hasPremium = true
                    if let expiration = transaction.expirationDate {
                        subscriptionStatus = .subscribed(expirationDate: expiration)
                    }
                } else {
                    subscriptionStatus = .expired
                }
                
            default:
                break
            }
        }
        
        isPremium = hasPremium
    }
    
    // MARK: - Feature Gating
    
    /// Check if a feature is available
    func isFeatureAvailable(_ feature: PremiumFeature) -> Bool {
        switch feature {
        case .basicGestures:
            return true // Always free
        case .customGestures, .shortcutsIntegration, .multipleProfiles, .advancedSensitivity:
            return isPremium
        }
    }
    
    /// Get display text for paywall
    func featureGateDescription(for feature: PremiumFeature) -> String {
        switch feature {
        case .basicGestures:
            return ""
        case .customGestures:
            return "Custom gestures require Premium"
        case .shortcutsIntegration:
            return "Shortcuts integration requires Premium"
        case .multipleProfiles:
            return "Multiple profiles require Premium"
        case .advancedSensitivity:
            return "Advanced sensitivity requires Premium"
        }
    }
    
    enum PremiumFeature {
        case basicGestures
        case customGestures
        case shortcutsIntegration
        case multipleProfiles
        case advancedSensitivity
    }
    
    // MARK: - Private
    
    private func handleSuccessfulPurchase(_ verification: VerificationResult<Transaction>) async {
        switch verification {
        case .verified(let transaction):
            // Grant premium
            await transaction.finish()
            await updatePremiumStatus()
            
        case .unverified(_, let error):
            print("Unverified transaction: \(error)")
        }
    }
    
    private func listenForTransactions() {
        updates = Task {
            for await result in Transaction.updates {
                switch result {
                case .verified(let transaction):
                    await handleTransactionUpdate(transaction)
                case .unverified(_, let error):
                    print("Unverified update: \(error)")
                }
            }
        }
    }
    
    private func handleTransactionUpdate(_ transaction: Transaction) async {
        await updatePremiumStatus()
        await transaction.finish()
    }
}
