//
//  Mail.swift
//  blocks
//
//  Created by よういち on 2020/06/11.
//  Copyright © 2020 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation
import overlayNetwork

public enum ClaimOnMail: String, Claim {
    public typealias ClaimType = ClaimOnMail
    case mail = "ML"
    case mailReply = "ML_"

    public init?(rawValue: String) {
        switch rawValue {
        case "ML":
            self = .mail
        case "ML_":
            self = .mailReply
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

    public var rawValue: String? {
        switch self {
        case .mail:
            return "ML"
        case .mailReply:
            return "ML_"
        }
    }
    
    public var rawValueWithAbstract: String? {
        switch self {
        case .mail:
            return "Message was Sent."
        case .mailReply:
            return "Reply to Message."
        }
    }

    public static func rawValue(_ claim: ClaimOnMail) -> String {
        switch claim {
        case .mail:
            return "ML"
        case .mailReply:
            return "ML_"
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
    
    public func construct(destination: OverlayNetworkAddressAsHexString, publicKeyForEncryption: PublicKeyForEncryption?, combinedSealedBox: String, description: String, attachedFileType: String) -> Object {
        Object(destination: destination, publicKeyForEncryption: publicKeyForEncryption, combinedSealedBox: combinedSealedBox, description: description, attachedFileType: attachedFileType)
    }
    public func construct(json: String) -> Object {
        if let jsonAsDictionary = json.jsonToDictionary {
            if let destination = jsonAsDictionary["Destination"],
                let publicKeyForEncryptionString = jsonAsDictionary["PublicKeyForEncryption"],
                let publicKeyForEncryption = publicKeyForEncryptionString.base64DecodedData,
                let combinedSealedBox = jsonAsDictionary["CombinedSealedBox"],
                let description = jsonAsDictionary["Description"],
                let attachedFileType = jsonAsDictionary["attachedFileType"] {
                return Object(destination: destination, publicKeyForEncryption: publicKeyForEncryption, combinedSealedBox: combinedSealedBox, description: description, attachedFileType: attachedFileType)
            }
        }
        return Object(destination: "")  //null
    }

    public func object(content: String) -> ClaimObject? {
        return nil
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
    
    public static let null = ClaimOnMail(rawValue: "")    //return nil

    public func replyBody(destinationDhtAddress: OverlayNetworkAddressAsHexString, description: String, signer: Signer, combinedSealedBox: Data? = nil, attachedFileType: FileType? = nil, personalDataAsEncrypted: Data?) -> [String: String]? {
        Log()
        guard let publicKeyAsBase64String = signer.publicKeyForEncryption?.rawRepresentation.base64String else {
            return nil
        }
        switch self {
        case .mail:
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
        guard let signer = node.signer(), let publicKeyForEncryptionAsData = signer.publicKeyForEncryption?.rawRepresentation else {
            return
        }

        let claimObject = self.construct(destination: destinationDhtAddress, publicKeyForEncryption: publicKeyForEncryptionAsData, combinedSealedBox: combinedSealedBox?.base64String ?? "", description: description, attachedFileType: attachedFileType?.rawValue ?? "")
        if let publicKeyAsData = signer.publicKeyAsData {
            Log()
            //Send Reply mail
            if let replyClaim = ClaimOnMail(rawValue: self.replyClaim),
                var transaction = TransactionType.mail.construct(claim: replyClaim, claimObject: claimObject, makerDhtAddressAsHexString: destinationDhtAddress, publicKey: publicKeyAsData, book: book, signer: signer, peerSigner: peerSigner) {
                transaction.send(node: node, signer: signer)
            }
        }
    }
}

/*
 Mail(Transaction Sub class)
 */
public struct Mail: Transaction {
    public static func == (lhs: Mail, rhs: Mail) -> Bool {
        guard let lhsTransactionId = lhs.transactionId, let rhsTransactionId = rhs.transactionId else {
            return false
        }
        return lhsTransactionId.equal(rhsTransactionId)
    }
    
    public var debitOnLeft: BK = Decimal.zero
    public var withdrawalDhtAddressOnLeft: OverlayNetworkAddressAsHexString = ""
    public var creditOnRight: BK = Decimal.zero
    public var depositDhtAddressOnRight: OverlayNetworkAddressAsHexString = ""
    public var feeForBooker: BK = TransactionType.mail.fee()

    var transactionIdPrefix: String {
        return "ML"
    }

    public var type: TransactionType = .mail
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
    
    public func isMatch<IsMatchArgumentA, IsMatchArgumentB>(type: TransactionType, claim: IsMatchArgumentA? = nil, dhtAddressAsHexString: IsMatchArgumentB? = nil) -> Bool {
        Log()
        guard type == .mail else {
            Log()
            return false
        }
        
        /*
         Check Parameter Type.
         */
        var claimOn: ClaimOnMail?
        var dhtAddressAsHexStringString: String?
        if claim == nil {
            if let dhtAddressAsHexString = dhtAddressAsHexString as? String {
                dhtAddressAsHexStringString = dhtAddressAsHexString
            } else {
                //Match all Mail Transactions.
                return true
            }
        } else {
            if let claim = claim as? ClaimOnMail {
                Log()
                claimOn = claim
                return false
            }
        }

        let transactionAsDictionary = self.contentAsDictionary
        let destination = transactionAsDictionary["Destination"] ?? ""
        guard let claimRawValue = transactionAsDictionary["Claim"], let claimValue = ClaimOnMail(rawValue: claimRawValue), claimValue != claimOn else {
            Log()
            return false
        }
        if destination == ClaimOnMail.destinationBroadCast || destination == dhtAddressAsHexStringString {
            Log()
            return true
        }
        Log(destination)
        return false
    }
    
    public init() {
        Log()
        self.date = nil
        self.transactionId = nil
        self.claim = ClaimOnMail.mail
        self.makerDhtAddressAsHexString = ""
        self.claimObject = ClaimOnMail.Object(destination: "")
        self.signature = nil
        self.publicKey = nil
//        self.book = Book(signature: Data.DataNull, currentDifficultyAsNonceLeadingZeroLength: 0)
        self.book = Book(signature: Data.DataNull)
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
