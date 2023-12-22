//
//  Transactions.swift
//  blocks
//
//  Created by よういち on 2023/10/17.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation

public struct Transactions {
    var transactions: [any Transaction]
    
    struct Maker {
        /*
         Set Transaction content to either dictionary or string.
         */
        let dictionary: [String: Any]?  //Dictionary Key must match as Transaction#useAsOperands
        let string: String?     //json string with utf8 encorded.
        let signer: Signer?
        let book: Book

        public init(book: Book, dictionary: [String : Any]? = nil, string: String? = nil, signer: Signer? = nil) {
            self.dictionary = dictionary
            self.string = string
            self.signer = signer
            self.book = book
        }
        
        public var dictionaryToTransaction: (any Transaction)? {
            Log(self.dictionary)
            if let dictionary = self.dictionary,
               let signatureBase64 = dictionary["signature"] as? String,
               let signature = signatureBase64.base64DecodedData,
               let publicKey = self.signer?.publicKeyAsData,

               let type = dictionary["type"] as? String,
               let typeAsTransactionType = TransactionType(rawValue: type),
               let claimAsString = dictionary["claim"] as? String, //Claim.rawValue
               let claim = typeAsTransactionType.construct(rawValue: claimAsString),
               let makerDhtAddressAsHexString = self.signer?.makerDhtAddressAsHexString,//これ
               /*
                claimObject example:
                
                {"Destination": destination,"PublicKeyForEncryption": publicKeyForEncryption,"CombinedSealedBox": combinedSealedBox,"Description": description,"PersonalData": personalDataAsJsonString}
                */
               let claimContentAsJsonString = dictionary["claimObject"],    //contents
               let transactionId = dictionary["transactionId"] as? String,
               let dateString = dictionary["date"] as? String {
                Log("claim: \(claim)")
                Log("claimContentAsJsonString: \(claimContentAsJsonString)")
                Log("publickey: \(publicKey.publicKeyToString)")
                Log("signature: \(signature.base64String)")
                Log("signatureData: \(signature.base64String)")
                Log("makerDhtAddressAsHexString: \(makerDhtAddressAsHexString)")
                Log("transactionId: \(transactionId)")
                Log("date: \(dateString)")
                
                var claimObject: ClaimObject?
                if claimContentAsJsonString is String {
                    Log()
                    if let contentString = claimContentAsJsonString as? String, let object = claim.object(content: contentString) {
                        claimObject = object
                    }
                } else if claimContentAsJsonString is Dictionary<String, Any>, let jsonAsData = try? JSONSerialization.data(withJSONObject: claimContentAsJsonString, options: []), let contentAsJson = jsonAsData.utf8String {
                    Log()
                    if let object = claim.object(content: contentAsJson) {
                        Log(object)
                        claimObject = object
                    }
                } else {
                    Log()
                }
                Log()
                if let claimObject = claimObject, let signer = self.signer {
                    Log()
                    return typeAsTransactionType.construct(claim: claim, claimObject: claimObject, makerDhtAddressAsHexString: makerDhtAddressAsHexString, publicKey: publicKey, signature: signature, book: self.book, signer: signer, transactionId: transactionId, date: dateString.date)
                }
            }
            return nil
        }

        public var stringToTransactions: [any Transaction]? {
            do {
                Log(self.string)
                if let data = self.string?.utf8DecodedData {
                    Log("\(data.utf8String ?? "")")
                    let jsonData = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
                    Log(jsonData)
                    if jsonData is Array<Any> {
                        if let jsonArray = jsonData as? [Any] {
                            let jsonDictionaryArray = jsonArray.map { (aObject) -> [String: Any]? in
                                return aObject as? [String: Any]
                            }
                            Log()
                            return jsonDictionaryArray.map { (jsonDictionary) -> (any Transaction)? in
                                let json = Maker(book: self.book, dictionary: jsonDictionary, signer: self.signer)
                                Log(jsonDictionary)
                                return json.dictionaryToTransaction
                            }.compactMap {
                                $0
                            }
                        }
                    } else {
                        if let jsonDictionary = jsonData as? [String: Any] {
                            let json = Maker(book: self.book, dictionary: jsonDictionary, signer: self.signer)
                            Log(jsonDictionary)
                            if let transaction = json.dictionaryToTransaction {
                                return [transaction]
                            }
                        }
                    }
                }
            } catch {
                Log("Error Fetching Json Data:\(error)")
            }
            return nil
        }
    }

    public init(transactions: [any Transaction]) {
        self.transactions = transactions
    }
    
    public mutating func send(node: Node, signer: Signer) {
        Log()
        do {
            if let _ = signer.privateKeyForSignature {
                Log()
                let newTransactions: [any Transaction] = try transactions.map {
                    var transaction = $0
                    try transaction.sign(with: signer)
                    return transaction
                }
                self.transactions = newTransactions
            }
        } catch {
            Log(error)
        }
        Log()
        publish(on: node, with: signer)
    }

    /*
     Publish     Transactionを発行する
     */
    public func publish(on node: Node, with signer: Signer) {
        Log()
        if let transaction = self.transactions.first {
            Log(transaction.signature?.toString)
            Log(signer.base64EncodedPublicKeyForSignatureString)
            var operands = [String]()
            if let signatureString = transaction.signature?.toString, let publicKeyAsBase64String = signer.base64EncodedPublicKeyForSignatureString, let dateString = transaction.date?.utcTimeString {
                operands = [transaction.type.rawValue, signatureString, publicKeyAsBase64String, transaction.makerDhtAddressAsHexString.toString, dateString, "\(self.transactions.count)"]
            }
            self.transactions.forEach {
                if let transactionId = $0.transactionId, let content = $0.claimObject.toJsonString(signer: $0.signer, peerSigner: $0.peerSigner) {
                    Log()
                    operands += [transactionId.transactionIdentificationToString, content]
                    Log(operands)
                }
            }
            
            if let predecessorIp = node.predecessor?.getIp {
                Command.publishTransaction.send(node: node, to: predecessorIp, operands: operands) { string in
                    Log(string)
                }
            }
            if let successorIp = node.successor?.getIp {
                Command.publishTransaction.send(node: node, to: successorIp, operands: operands) { string in
                    Log(string)
                }
            }
            if let babysitterIp = node.babysitterNode?.getIp {
                Command.publishTransaction.send(node: node, to: babysitterIp, operands: operands) { string in
                    Log(string)
                }
            }
        }
    }
}
