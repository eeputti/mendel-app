#if !WIDGET_EXTENSION
//
// PurchaseManager.swift
// One-time unlock purchase flow.
//

import Foundation
import StoreKit

@Observable
final class PurchaseManager {
    var isUnlocked = false
    var isLoading = false
    var error: String?

    var hasPremiumAccess: Bool {
        isUnlocked || developerPremiumOverrideEnabled
    }

    private var product: Product?
    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = listenForTransactions()
        Task { await loadProduct() }
        Task { await restoreIfNeeded() }
    }

    deinit {
        transactionListener?.cancel()
    }

    func purchase() async {
        guard let product else {
            error = "product unavailable."
            return
        }

        isLoading = true
        error = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                isUnlocked = true
            case .userCancelled:
                break
            case .pending:
                error = "purchase is pending."
            @unknown default:
                break
            }
        } catch {
            self.error = "purchase failed."
        }
        isLoading = false
    }

    func restore() async {
        isLoading = true
        error = nil
        do {
            try await AppStore.sync()
            await restoreIfNeeded()
        } catch {
            self.error = "couldn't restore."
        }
        isLoading = false
    }

    var formattedPrice: String {
        product?.displayPrice ?? "€14.99"
    }

    private var developerPremiumOverrideEnabled: Bool {
#if DEBUG
        true
#else
        false
#endif
    }

    private func loadProduct() async {
        do {
            let products = try await Product.products(for: ["com.dipworks.mendel.unlock"])
            product = products.first
        } catch {
            self.error = "couldn't load product."
        }
    }

    private func restoreIfNeeded() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == "com.dipworks.mendel.unlock",
               transaction.revocationDate == nil {
                isUnlocked = true
                return
            }
        }
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result,
                   transaction.productID == "com.dipworks.mendel.unlock" {
                    await transaction.finish()
                    await MainActor.run { self.isUnlocked = true }
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreErr.unverified
        case .verified(let value):
            return value
        }
    }

    enum StoreErr: Error {
        case unverified
    }
}
#endif
