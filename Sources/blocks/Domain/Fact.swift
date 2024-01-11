//
//  Fact.swift
//  blocks
//
//  Created by よういち on 2020/06/11.
//  Copyright © 2020 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation
import overlayNetwork

public enum ClaimOnFact: String, Claim {
    public var rawValue: String? {
        switch self {
        case .a:
            return "a"
        case .aReply:
            return "aReply"
        }
    }

    public var rawValueWithAbstract: String? {
        switch self {
        case .a:
            return "..."
        case .aReply:
            return "..."
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

    public typealias ClaimType = ClaimOnFact
    case a = ""
    case aReply = "_"

    public init?(rawValue: String) {
        switch rawValue {
        case "a":
            self = .a
        case "aReply":
            self = .aReply
        default:
            return nil
        }
    }
    
    public var fee: Double {
        switch self {
        default:
            return 0
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

    public static func rawValue(_ claim: ClaimOnFact) -> String {
        switch claim {
        case .a:
            return "FT"
        case .aReply:
            return "FT_"
        }
    }
    
    public static let null = ClaimOnFact(rawValue: "")    //return nil

    public func replyBody(destinationDhtAddress: OverlayNetworkAddressAsHexString, description: String, signer: Signer, combinedSealedBox: Data? = nil, attachedFileType: FileType? = nil, personalDataAsEncrypted: Data?) -> [String: String]? {
        Log()
        guard let publicKeyAsBase64String = signer.publicKeyForEncryption?.rawRepresentation.base64String else {
            return nil
        }
        switch self {
        case .a:
            return [
                "Destination": destinationDhtAddress.toString,
                "Claim": self.replyClaim,   //Reply Suitable as Birth Person Whether
                "PublicKeyForEncryption": publicKeyAsBase64String,
                "CombinedSealedBox": combinedSealedBox?.base64String ?? "", //image binary or zip file
                "attachedFileType": attachedFileType?.rawValue ?? "",
                "Description": description,
            ]
        default:
            return [
                "Destination": destinationDhtAddress.toString,
                "Claim": self.replyClaim,
                "PublicKeyForEncryption": publicKeyAsBase64String,
                "Description": description,
            ]
        }
    }
    
    public func reply(to destinationDhtAddress: OverlayNetworkAddressAsHexString, description: String, node: Node, combinedSealedBox: Data?, attachedFileType: FileType?, personalData: ClaimOnPerson.PersonalData?, book: Book, peerSigner: Signer) {
        guard let signer = node.signer() else {
            return
        }
        let claimObject = ClaimOnFact.Object(destination: destinationDhtAddress)
        if let publicKeyAsData = signer.publicKeyAsData {
            Log()
            switch self {
            case .a:
                if var transaction = TransactionType.mail.construct(claim: self, claimObject: claimObject, makerDhtAddressAsHexString: destinationDhtAddress, publicKey: publicKeyAsData, book: book, signer: signer, peerSigner: peerSigner) {
                    transaction.send(node: node, signer: signer)
                }
            case .aReply:
                if var transaction = TransactionType.mail.construct(claim: self, claimObject: claimObject, makerDhtAddressAsHexString: destinationDhtAddress, publicKey: publicKeyAsData, book: book, signer: signer, peerSigner: peerSigner) {
                    transaction.send(node: node, signer: signer)
                }
            }
        }
    }
}

/*
 Fact(Sub class)        アプリケーションを登録する（ユニークトランザクション）
     FactしたPersonには、MoveInの通知が届く

 */
public struct Fact: Transaction {
    public static func == (lhs: Fact, rhs: Fact) -> Bool {
        guard let lhsTransactionId = lhs.transactionId, let rhsTransactionId = rhs.transactionId else {
            return false
        }
        return lhsTransactionId.equal(rhsTransactionId)
    }
    
    public var debitOnLeft: BK = Decimal.zero
    public var withdrawalDhtAddressOnLeft: OverlayNetworkAddressAsHexString = ""
    public var creditOnRight: BK = Decimal.zero
    public var depositDhtAddressOnRight: OverlayNetworkAddressAsHexString = ""
    public var feeForBooker: BK = TransactionType.fact.fee()

    public func isMatch<ArgumentA, ArgumentB>(type: TransactionType, claim: ArgumentA?, dhtAddressAsHexString: ArgumentB?) -> Bool {
        guard type == .fact else {
            Log()
            return false
        }
        
        /*
         Check Parameter Type.
         */
        var claimOn: ClaimOnFact?
        var dhtAddressAsHexStringString: String?
        if claim == nil {
            if let dhtAddressAsHexString = dhtAddressAsHexString as? String {
                dhtAddressAsHexStringString = dhtAddressAsHexString
            } else {
                //Match all Mail Transactions.
                return true
            }
        } else {
            if let claim = claim as? ClaimOnFact {
                Log()
                claimOn = claim
                return false
            }
        }
        
        let transactionAsDictionary = self.contentAsDictionary
        let destination = transactionAsDictionary["Destination"] ?? ""
        guard let claimRawValue = transactionAsDictionary["Claim"], let claimValue = ClaimOnFact(rawValue: claimRawValue), claimValue != claimOn else {
            Log()
            return false
        }
        if destination == ClaimOnFact.destinationBroadCast || destination == dhtAddressAsHexStringString {
            Log()
            return true
        }
        Log(destination)
        return false
    }

    var transactionIdPrefix: String {
        return "FT"
    }

    public var type: TransactionType = .fact
    public var claim: any Claim

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
        self.claim = ClaimOnFact.a
        self.makerDhtAddressAsHexString = ""
        self.claimObject = ClaimOnFact.Object(destination: "")
        self.signature = nil
        self.publicKey = nil
        self.book = Book(signature: Data.DataNull, currentDifficultyAsNonceLeadingZeroLength: 0)
        self.signer = Signer()
    }

    public init(claim: any Claim, claimObject: ClaimObject, makerDhtAddressAsHexString: OverlayNetworkAddressAsHexString, publicKey: PublicKey, signature: Signature? = nil, book: Book, signer: Signer, peerSigner: Signer? = nil, transactionId: TransactionIdentification? = nil, date: Date? = Date.now, debitOnLeft: BK, creditOnRight: BK, withdrawalDhtAddressOnLeft: String, depositDhtAddressOnRight: String) {
        Log()
        self.makerDhtAddressAsHexString = makerDhtAddressAsHexString
        self.claimObject = claimObject
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
