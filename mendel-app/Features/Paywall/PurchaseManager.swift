import StoreKit
import SwiftUI

// MARK: - Product IDs
// Register these exact strings in App Store Connect → In-App Purchases

enum MendelProduct {
    static let unlock = "com.dipworks.mendel.unlock"  // One-time, Non-consumable
}

// MARK: - Purchase Manager

@Observable
final class PurchaseManager {

    // MARK: State
    var isUnlocked: Bool = false
    var isLoading:  Bool = false
    var error:      String? = nil

    private var product: Product? = nil
    private var transactionListener: Task<Void, Never>? = nil

    init() {
        transactionListener = listenForTransactions()
        Task { await loadProduct() }
        Task { await restoreIfNeeded() }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Public API

    /// Call from the paywall "Unlock" button.
    func purchase() async {
        guard let product else {
            error = "product unavailable — try again later."
            return
        }

        isLoading = true
        error = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let tx = try checkVerified(verification)
                await tx.finish()
                isUnlocked = true
            case .userCancelled:
                break
            case .pending:
                error = "purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            self.error = "purchase failed. try again."
        }

        isLoading = false
    }

    /// Restore on app launch or user tap.
    func restore() async {
        isLoading = true
        error = nil
        do {
            try await AppStore.sync()
            await restoreIfNeeded()
        } catch {
            self.error = "couldn't restore — check your Apple ID."
        }
        isLoading = false
    }

    var formattedPrice: String {
        product?.displayPrice ?? "€14.99"
    }

    // MARK: - Private

    private func loadProduct() async {
        do {
            let products = try await Product.products(for: [MendelProduct.unlock])
            product = products.first
        } catch {
            self.error = "couldn't load product."
        }
    }

    private func restoreIfNeeded() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productID == MendelProduct.unlock,
               tx.revocationDate == nil {
                isUnlocked = true
                return
            }
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                if case .verified(let tx) = result,
                   tx.productID == MendelProduct.unlock {
                    await tx.finish()
                    await MainActor.run { self.isUnlocked = true }
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.unverified
        case .verified(let value): return value
        }
    }

    enum StoreError: Error { case unverified }
}
