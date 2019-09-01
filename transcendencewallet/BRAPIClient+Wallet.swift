//
//  BRAPIClient+Wallet.swift
//  breadwallet
//
//  Created by Samuel Sutch on 4/2/17.
//  Copyright © 2017 breadwallet LLC. All rights reserved.
//

import Foundation

private let fallbackRatesURL = "https://bitpay.com/api/rates"
private let dogecashMultiplierURL = "https://api.coinmarketcap.com/v1/ticker/dogecash/"

extension BRAPIClient {
    func feePerKb(_ handler: @escaping (_ fees: Fees, _ error: String?) -> Void) {

        let fastestFee = Fees.defaultFees.fastest
            let regularFee = Fees.defaultFees.regular
            let economyFee = Fees.defaultFees.economy
       let errStr: String? = nil
            handler(Fees(fastest: fastestFee, regular: regularFee, economy: economyFee), errStr)
        }
    
    func dogecashMultiplier(_ handler: @escaping (_ mult: Double, _ error: String?) -> Void) {
        let request = URLRequest(url: URL(string: dogecashMultiplierURL)!)
        let task = dataTaskWithRequest(request) { (data, response, error) in
            do {
                
                if error == nil, let data = data,
                    let parsedData = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [[String:Any]] {
                    guard let arr = parsedData.first else {
                        return handler(0.00, "\(String(describing: self.dogecashMultiplier)) didn't return an array")
                    }
                    guard let ratio : Double = Double(arr["price_btc"] as! String) else {
                        return handler(0.00, "Error getting from arr")
                    }
                    print("BMEX Ratio \(ratio)");
                    return handler(ratio, nil)
                } else {
                    return handler(0.00, "BMEX Ratio Error fetching from DogeCash multiplier url")
                }
                
                
            } catch let error {
                return handler(0.00, "BMEX Ratio price_btc data error caught \(error)");
            }
        }
        task.resume()
    }
    func exchangeRates(code: String, isFallback: Bool = false, _ ratio : Double, _ handler: @escaping (_ rates: [Rate],
        _ multiplier: Double, _ error: String?) -> Void) {
        let param = ""
        let request = isFallback ? URLRequest(url: URL(string: fallbackRatesURL)!) : URLRequest(url: url("/rates\(param)"))
        let task = dataTaskWithRequest(request) { (data, response, error) in
            if error == nil, let data = data,
                let parsedData = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) {
                if isFallback {
                    guard let array = parsedData as? [Any] else {
                        return handler([], 1.0, "/rates didn't return an array")
                    }
                    handler(array.compactMap { Rate(dictionary: $0, ratio: ratio) }, 1.0, nil)
                } else {
                    guard let dict = parsedData as? [String: Any],
                        let array = dict["body"] as? [Any] else {
                            return self.exchangeRates(code: code, isFallback: true, ratio, handler)
                    }
                    handler(array.compactMap { Rate(dictionary: $0, ratio: ratio) }, 1.0, nil)
                }
            } else {
                if isFallback {
                    handler([], 1.0, "Error fetching from fallback url")
                } else {
                    self.exchangeRates(code: code, isFallback: true, ratio, handler)
                }
            }
        }
        task.resume()
    }
    
    func savePushNotificationToken(_ token: Data) {
        var req = URLRequest(url: url("/me/push-devices"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let reqJson = [
            "token": token.hexString,
            "service": "apns",
            "data": [   "e": pushNotificationEnvironment(),
                        "b": Bundle.main.bundleIdentifier!]
            ] as [String : Any]
        do {
            let dat = try JSONSerialization.data(withJSONObject: reqJson, options: .prettyPrinted)
            req.httpBody = dat
        } catch (let e) {
            log("JSON Serialization error \(e)")
            return
        }
        dataTaskWithRequest(req as URLRequest, authenticated: true, retryCount: 0) { (dat, resp, er) in
            let dat2 = String(data: dat ?? Data(), encoding: .utf8)
            self.log("save push token resp: \(String(describing: resp)) data: \(String(describing: dat2))")
        }.resume()
    }

    func deletePushNotificationToken(_ token: Data) {
        var req = URLRequest(url: url("/me/push-devices/apns/\(token.hexString)"))
        req.httpMethod = "DELETE"
        dataTaskWithRequest(req as URLRequest, authenticated: true, retryCount: 0) { (dat, resp, er) in
            self.log("delete push token resp: \(String(describing: resp))")
            if let statusCode = resp?.statusCode {
                if statusCode >= 200 && statusCode < 300 {
                    UserDefaults.pushToken = nil
                    self.log("deleted old token")
                }
            }
        }.resume()
    }

    func publishBCashTransaction(_ txData: Data, callback: @escaping (String?) -> Void) {
        var req = URLRequest(url: url("/bch/publish-transaction"))
        req.httpMethod = "POST"
        req.setValue("application/bcashdata", forHTTPHeaderField: "Content-Type")
        req.httpBody = txData
        dataTaskWithRequest(req as URLRequest, authenticated: true, retryCount: 0) { (dat, resp, er) in
            if let statusCode = resp?.statusCode {
                if statusCode >= 200 && statusCode < 300 {
                    callback(nil)
                } else if let data = dat, let errorString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                    callback(errorString as String)
                } else {
                    callback("\(statusCode)")
                }
            }
        }.resume()
    }
}

private func pushNotificationEnvironment() -> String {
    return E.isDebug ? "d" : "p" //development or production
}
