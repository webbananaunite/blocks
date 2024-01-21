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
        let signer: Signer?   //make by each transaction
        let book: Book

        public init(book: Book, dictionary: [String : Any]? = nil, string: String? = nil, signer: Signer? = nil) {
            self.dictionary = dictionary
            self.string = string
            self.signer = signer
            self.book = book
        }
        
        public var dictionaryToTransaction: (any Transaction)? {
//            let publicKeyString = dictionary["publicKey"] as? String
//            let makerDhtAddressAsHexString = dictionary["makerDhtAddressAsHexString"] as? String
            /*
             Optional([
             "claimObject": {
                 CombinedSealedBox = "";
                 Description = "";
                 Destination = BroadCast;
                 PersonalData = "";
                 PublicKeyForEncryption = "1kzl6vkw8RgPaem4mdQan5Q7QnZz97yqYHq1qU7Idy0=";
             }, 
             "date": 2024-01-17T05:02:29.596Z,
             "type": person,
             "claim": FT,
             "signature": uNXK4WYdOuhwyA06PhUTuepFkeQDddHV5OTTS0yzm1qO44zd+ccTuh3/XadSqGtq693YFChPBcMDnkKuO2ZkDA==,
             "transactionId": PScf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e
             ])
             */
            Log(self.dictionary)
//            guard let dictionary = self.dictionary else {return nil}
//            let signatureBase64 = dictionary["signature"] as? String
//            let signature = signatureBase64?.base64DecodedData
//            let publicKeyString = dictionary["publicKey"] as? String
//            let publicKeyAsData = publicKeyString?.base64DecodedData
//            let makerDhtAddressAsHexString = dictionary["makerDhtAddressAsHexString"] as? String
//            let type = dictionary["type"] as? String
//            let typeAsTransactionType = TransactionType(rawValue: type ?? "")
//            let claimAsString = dictionary["claim"] as? String
//            let claim = typeAsTransactionType?.construct(rawValue: claimAsString ?? "")
//            let claimContentAsJsonString = dictionary["claimObject"]
//            let transactionId = dictionary["transactionId"] as? String
//            let dateString = dictionary["date"] as? String

            
            if let dictionary = self.dictionary,
               let signatureBase64 = dictionary["signature"] as? String,
               let signature = signatureBase64.base64DecodedData,
               
//               let publicKeyString = dictionary["publicKey"] as? String,
//               let publicKeyAsData = publicKeyString.base64DecodedData,
//               let makerDhtAddressAsHexString = dictionary["makerDhtAddressAsHexString"] as? String,
                let signer = self.signer,
               let type = dictionary["type"] as? String,
               let typeAsTransactionType = TransactionType(rawValue: type),
               let claimAsString = dictionary["claim"] as? String, //Claim.rawValue
               let claim = typeAsTransactionType.construct(rawValue: claimAsString),
               /*
                claimObject example:
                
                {"Destination": destination,"PublicKeyForEncryption": publicKeyForEncryption,"CombinedSealedBox": combinedSealedBox,"Description": description,"PersonalData": personalDataAsJsonString}
                */
               let claimContentAsJsonString = dictionary["claimObject"],    //contents
               let transactionId = dictionary["transactionId"] as? String,
               let dateString = dictionary["date"] as? String {
                Log("claim: \(claim)")
                Log("claimContentAsJsonString: \(claimContentAsJsonString)")
                Log("publickey: \(signer.publicKeyAsData?.publicKeyToString)")
                Log("signature: \(signature.base64String)")
                Log("signatureData: \(signature.base64String)")
                Log("makerDhtAddressAsHexString: \(signer.makerDhtAddressAsHexString)")
                Log("transactionId: \(transactionId)")
                Log("date: \(dateString)")
//                let signer = Signer(publicKeyAsData: publicKeyAsData, makerDhtAddressAsHexString: makerDhtAddressAsHexString)
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
                if let claimObject = claimObject {
                    Log()
                    return typeAsTransactionType.construct(claim: claim, claimObject: claimObject, makerDhtAddressAsHexString: signer.makerDhtAddressAsHexString, publicKey: signer.publicKeyAsData, signature: signature, book: self.book, signer: signer, transactionId: transactionId, date: dateString.date)
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
                                let jsonMaker = Maker(book: self.book, dictionary: jsonDictionary, signer: self.signer)
                                Log(jsonDictionary)
                                return jsonMaker.dictionaryToTransaction
                            }.compactMap {
                                $0
                            }
                        }
                    } else {
                        if let jsonDictionary = jsonData as? [String: Any] {
                            let jsonMaker = Maker(book: self.book, dictionary: jsonDictionary, signer: self.signer)
                            Log(jsonDictionary)
                            if let transaction = jsonMaker.dictionaryToTransaction {
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
