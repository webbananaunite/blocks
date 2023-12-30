//
//  Pay.swift
//  blocks
//
//  Created by よういち on 2023/10/13.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation
import overlayNetwork

public enum ClaimOnPay: String, Claim {
    public typealias ClaimType = ClaimOnPay
    case bookerFee = "BF"
    case bookerFeeReply = "BF_"

    public var rawValue: String? {
        switch self {
        case .bookerFee:
            return "BF"
        case .bookerFeeReply:
            return "BF_"
        }
    }
    
    public var fee: Decimal {
        switch self {
        case .bookerFee:
            return 10
        default:
            return 0
        }
    }

    public struct Object: ClaimObject {
        public let destination: OverlayNetworkAddressAsHexString
        public let publicKeyForEncryption: PublicKeyForEncryption?
        public let combinedSealedBox: String
        public let description: String
        public let attachedFileType: String
        
        public init(destination: OverlayNetworkAddressAsHexString, publicKeyForEncryption: PublicKeyForEncryption? = nil, combinedSealedBox: String = "", description: String = "", attachedFileType: String = "") {
            self.destination = destination
            self.publicKeyForEncryption = publicKeyForEncryption
            self.combinedSealedBox = combinedSealedBox
            self.description = description
            self.attachedFileType = attachedFileType
        }
        
        public func toDictionary(signer: Signer? = nil, peerSigner: Signer? = nil) -> [String: String]? {
            return [
                "Destination": destination.toString,
                "PublicKeyForEncryption": publicKeyForEncryption?.publicKeyForEncryptionToString ?? "",
                "CombinedSealedBox": combinedSealedBox, //image binary or zip file
                "Description": description,
            ]
        }
        public func toJsonString(signer: Signer? = nil, peerSigner: Signer? = nil) -> String? {
            return [
                "Destination": destination.toString,
                "PublicKeyForEncryption": publicKeyForEncryption?.publicKeyForEncryptionToString ?? "",
                "CombinedSealedBox": combinedSealedBox, //image binary or zip file
                "Description": description,
            ].dictionaryToJsonString
        }
    }

    public func object(content: String) -> ClaimObject? {
        return nil
    }

    public init?(rawValue: String) {
        switch rawValue {
        case "BF":
            self = .bookerFee
        case "BF_":
            self = .bookerFeeReply
        default:
            return nil
        }
    }
    public var replyClaim: String {
        return Self.rawValue(self) + "_"
    }
    public var sendClaim: String {
        if Self.rawValue(self).contains("_") {
            return Self.rawValue(self).replacingOccurrences(of: "_", with: "")
        }
        return Self.rawValue(self)
    }

    public func isReply() -> Bool {
        if Self.rawValue(self).contains("_") {
            return true
        }
        return false
    }

    public static func rawValue(_ claim: ClaimOnPay) -> String {
        switch claim {
        case .bookerFee:
            return "BF"
        case .bookerFeeReply:
            return "BF_"
        }
    }
    
    public static let null = ClaimOnPay(rawValue: "")    //return nil

    public func replyBody(destinationDhtAddress: OverlayNetworkAddressAsHexString, description: String, signer: Signer, combinedSealedBox: Data? = nil, attachedFileType: FileType? = nil, personalDataAsEncrypted: Data?) -> [String: String]? {
        Log()
        guard let publicKeyAsBase64String = signer.publicKeyForEncryption?.rawRepresentation.base64String else {
            return nil
        }
        switch self {
        case .bookerFee:
            return [
                "Destination": destinationDhtAddress.toString,
                "Claim": self.replyClaim,   //Reply Suitable as Birth Person Whether
                "PublicKeyForEncryption": publicKeyAsBase64String,
                "CombinedSealedBox": combinedSealedBox?.base64String ?? "", //image binary or zip file
                "attachedFileType": attachedFileType?.rawValue ?? "",
                "Description": description,
            ]
        default:
            return nil
        }
    }
    
    public func reply(to destinationDhtAddress: OverlayNetworkAddressAsHexString, description: String, node: Node, combinedSealedBox: Data?, attachedFileType: FileType?, personalData: ClaimOnPerson.PersonalData?, book: Book, peerSigner: Signer) {
        guard let signer = node.signer() else {
            return
        }
        if let mailBody = self.replyBody(destinationDhtAddress: destinationDhtAddress, description: description, signer: signer, combinedSealedBox: combinedSealedBox, personalDataAsEncrypted: personalData?.encrypt(signer: signer, peerSigner: peerSigner)) {
            if let publicKeyAsBase64String = signer.base64EncodedPublicKeyForSignatureString, let dataAsJson = try? JSONSerialization.data(withJSONObject: mailBody, options: []) {
                Log()
                let textAsBase64String = dataAsJson.base64String
                Log("Data as base64 string: \(textAsBase64String)")
                
                switch self {
                    //#pending
//                case .bookerFee:
//                    if var transaction = TransactionType.mail.construct(makerDhtAddressAsHexString: destinationDhtAddress, content: textAsBase64String, signer: signer, publicKey: publicKeyAsBase64String, book: book, claim: self) {
//                        transaction.send(node: node, signer: signer)
//                    }
//                case .bookerFeeReply:
//                    if var transaction = TransactionType.mail.construct(makerDhtAddressAsHexString: destinationDhtAddress, content: textAsBase64String, signer: signer, publicKey: publicKeyAsBase64String, book: book, claim: self) {
//                        transaction.send(node: node, signer: signer)
//                    }
                default:
                    break
                }
            }
        }
    }
    
}

public struct Pay: Transaction {
    public var claim: any Claim
    
    public static func == (lhs: Pay, rhs: Pay) -> Bool {
        guard let lhsTransactionId = lhs.transactionId, let rhsTransactionId = rhs.transactionId else {
            return false
        }
        return lhsTransactionId.equal(rhsTransactionId)
    }
    
    public var debitOnLeft: BK = Decimal.zero
    public var withdrawalDhtAddressOnLeft: OverlayNetworkAddressAsHexString = ""
    public var creditOnRight: BK = Decimal.zero
    public var depositDhtAddressOnRight: OverlayNetworkAddressAsHexString = ""
    public var feeForBooker: BK = TransactionType.pay.fee()

    public func isMatch<ArgumentA, ArgumentB>(type: TransactionType, claim: ArgumentA?, dhtAddressAsHexString: ArgumentB?) -> Bool {
        guard type == .pay else {
            Log()
            return false
        }
        
        /*
         Check Parameter Type.
         */
        var claimOn: ClaimOnPay?
        var dhtAddressAsHexStringString: String?
        if claim == nil {
            if let dhtAddressAsHexString = dhtAddressAsHexString as? String {
                dhtAddressAsHexStringString = dhtAddressAsHexString
            } else {
                //Match all Mail Transactions.
                return true
            }
        } else {
            if let claim = claim as? ClaimOnPay {
                Log()
                claimOn = claim
                return false
            }
        }
        
        let transactionAsDictionary = self.contentAsDictionary
        let destination = transactionAsDictionary["Destination"] ?? ""
        guard let claimRawValue = transactionAsDictionary["Claim"], let claimValue = ClaimOnPay(rawValue: claimRawValue), claimValue != claimOn else {
            Log()
            return false
        }
        if destination == ClaimOnPay.destinationBroadCast || destination == dhtAddressAsHexStringString {
            Log()
            return true
        }
        Log(destination)
        return false
    }
    
    var transactionIdPrefix: String {
        return "BK"   //Default Transaction Prefix
    }
    public var type: TransactionType = .pay
    public var makerDhtAddressAsHexString: OverlayNetworkAddressAsHexString
    public var claimObject: ClaimObject
    
    public var signature: Signature?
    public var publicKey: PublicKey?
    public var signer: Signer
    public var peerSigner: Signer?

    public var book: Book

    public var transactionId: TransactionIdentification?
    public var date: Date?

    public init() {
        Log()
        self.date = nil
        self.transactionId = nil
        self.claim = ClaimOnPay.bookerFee
        self.makerDhtAddressAsHexString = ""
        self.claimObject = ClaimOnPay.Object(destination: "")
        self.signature = nil
        self.publicKey = nil
        self.book = Book(signature: Data.DataNull, currentDifficultyAsNonceLeadingZeroLength: 0)
        self.signer = Signer()
    }
    
    public init(claim: any Claim, claimObject: ClaimObject, makerDhtAddressAsHexString: OverlayNetworkAddressAsHexString, publicKey: PublicKey, signature: Signature? = nil, book: Book, signer: Signer, peerSigner: Signer? = nil, transactionId: TransactionIdentification? = nil, date: Date? = Date.now, debitOnLeft: BK, creditOnRight: BK, withdrawalDhtAddressOnLeft: String, depositDhtAddressOnRight: String) {
        Log()
        self.makerDhtAddressAsHexString = makerDhtAddressAsHexString
        self.claimObject = claimObject
        /*
         ↑
         出金(入力): 複数あり
         支払い(出力): 複数あり
         */
        
        self.publicKey = publicKey
        self.signer = signer
        self.peerSigner = peerSigner
        
        self.book = book
        self.claim = claim
        self.debitOnLeft = debitOnLeft
        self.withdrawalDhtAddressOnLeft = withdrawalDhtAddressOnLeft
        self.creditOnRight = creditOnRight
        self.depositDhtAddressOnRight = depositDhtAddressOnRight

        if transactionId == nil {
            Log()
            /*
             transactionの内容と現在時間をハッシュしてUniqueな文字列を生成する
             */
            if let hashedString = self.useAsHash.hashedStringAsHex?.toString {
                self.transactionId = self.transactionIdPrefix + hashedString
            }
        } else {
            Log()
            self.transactionId = transactionId
        }
        self.date = date
        if signature != nil {
            self.signature = signature
        } else {
            do {
                try self.sign(with: signer)
            } catch {
                Log(error)
            }
        }
    }
}
