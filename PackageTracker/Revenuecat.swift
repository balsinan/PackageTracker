//
//  Revenuecat.swift
//  PackageTracker
//
//  Created by Merve Çelik on 5.05.2026.
//

import Foundation
import RevenueCat

let rcId = "appl_wdBqQhapTPSvSRICUYDzwPnKCKZ"

func configureRevenueCat() {
    Purchases.configure(withAPIKey: rcId)
}

func isPremium() -> Bool {
   // return true //FIXME: DUZELT
    return UserDefaults.standard.bool(forKey: "isPremium")
}

enum PurchaseCompletion {
    case cancel
    case success
}

enum PaywallError: Error {
    case paywallNotFound
}

enum IapTypeAdapty {
    case weeklyFreeTrial
    case yearly
}

enum Productidentifier: String, CaseIterable {
    case yearlyIdentifier = "com.blackcell.package.transfer.yearly"
    case weeklyTrialIdentifier =  "com.blackcell.package.transfer.weekly"
}

class IapService {

    static let sharedInstance = IapService()
    
    var weeklyProduct: StoreProduct?
    var yearlyProduct: StoreProduct?
    var offerProduct: StoreProduct?
    
    var selectedRCProduct: StoreProduct?
    
    public typealias onCompleteProductHandler = ((Bool,Error?)->())
    
    func getProducts(onComplete : @escaping onCompleteProductHandler) {
        
        Purchases.shared.getOfferings { offerings, error in
            
            if let err = error {
                onComplete(false, err)
                return
            }
            
            if let offering = offerings?.current?.availablePackages {
                for package in offering {
                    if package.storeProduct.productIdentifier == Productidentifier.yearlyIdentifier.rawValue {
                        self.yearlyProduct = package.storeProduct
                    } else if package.storeProduct.productIdentifier == Productidentifier.weeklyTrialIdentifier.rawValue {
                        self.weeklyProduct = package.storeProduct
                    }
                }
                onComplete(true, nil)
            } else {
                onComplete(false, nil)
            }
        }
    }
    
    func checkIapValidation(onComplete: @escaping onCompleteProductHandler) {
        Purchases.shared.getCustomerInfo { info, error in
            DispatchQueue.main.async {
                if let err = error {
                    onComplete(false, err)
                    return
                }
                guard let customerInfo = info else {
                    onComplete(false, nil)
                    return
                }
                if customerInfo.activeSubscriptions.count > 0 {
                    UserDefaults.standard.set(true, forKey: "isPremium")
                    onComplete(true, nil)
                } else {
                    UserDefaults.standard.set(false, forKey: "isPremium")
                    onComplete(false, nil)
                }
            }
        }
    }
    
    func startPurchase(onComplete: @escaping onCompleteProductHandler) {
        guard let product = self.selectedRCProduct else {
            onComplete(false, nil)
            return
        }
        Purchases.shared.purchase(product: product) { transaction, info, error, cancelled in
            if cancelled {
                onComplete(false, nil)
                return
            }

            if let err = error {
                onComplete(false, err)
                return
            }

            guard let customerInfo = info else {
                onComplete(false, nil)
                return
            }

            if customerInfo.activeSubscriptions.count > 0 {
                UserDefaults.standard.set(true, forKey: "isPremium")
                onComplete(true, nil)
            } else {
                onComplete(false, nil)
            }
        }
    }
    
    func restorePurchase(onComplete: @escaping onCompleteProductHandler) {
        Purchases.shared.restorePurchases { info, error in
            if let err = error {
                onComplete(false, err)
                return
            }
            guard let customerInfo = info else {
                onComplete(false, nil)
                return
            }
            if customerInfo.activeSubscriptions.count > 0 {
                UserDefaults.standard.set(true, forKey: "isPremium")
                onComplete(true, nil)
            } else {
                UserDefaults.standard.set(false, forKey: "isPremium")
                onComplete(false, nil)
            }
        }
    }
}
