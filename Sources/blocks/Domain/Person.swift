//
//  Person.swift
//  blocks
//
//  Created by よういち on 2020/06/08.
//  Copyright © 2020 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation
import overlayNetwork

public enum ClaimOnPerson: String, Claim {
    public typealias ClaimType = ClaimOnPerson
    case findTaker = "FT"
    case findTakerReply = "FT_"
    case askForTaker = "AT"
    case askForTakerReply = "AT_"
    case demandBasicIncome = "BI"
    case demandBasicIncomeReply = "BI_"
    case born = "BN"

    public init?(rawValue: String) {
        switch rawValue {
        case "FT":
            self = .findTaker
        case "FT_":
            self = .findTakerReply
        case "AT":
            self = .askForTaker
        case "AT_":
            self = .askForTakerReply
        case "BI":
            self = .demandBasicIncome
        case "BI_":
            self = .demandBasicIncomeReply
        case "BN":
            self = .born
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
        case .findTaker:
            return "FT"
        case .findTakerReply:
            return "FT_"
        case .askForTaker:
            return "AT"
        case .askForTakerReply:
            return "AT_"
        case .demandBasicIncome:
            return "BI"
        case .demandBasicIncomeReply:
            return "BI_"
        case .born:
            return "BN"
        }
    }

    public static func rawValue(_ claim: ClaimOnPerson) -> String {
        switch claim {
        case .findTaker:
            return "FT"
        case .findTakerReply:
            return "FT_"
        case .askForTaker:
            return "AT"
        case .askForTakerReply:
            return "AT_"
        case .demandBasicIncome:
            return "BI"
        case .demandBasicIncomeReply:
            return "BI_"
        case .born:
            return "BN"
        }
    }

    public struct Object: ClaimObject {
        public let destination: OverlayNetworkAddressAsHexString
        public let publicKeyForEncryption: PublicKeyForEncryption?
        public let combinedSealedBox: String
        public let description: String
        public let attachedFileType: String
        public let personalData: PersonalData
        
        init(destination: OverlayNetworkAddressAsHexString, publicKeyForEncryption: PublicKeyForEncryption? = nil, combinedSealedBox: String = "", description: String = "", attachedFileType: String = "", personalData: PersonalData = PersonalData.null) {
            Log()
            self.destination = destination
            self.publicKeyForEncryption = publicKeyForEncryption
            self.combinedSealedBox = combinedSealedBox
            self.description = description
            self.attachedFileType = attachedFileType
            self.personalData = personalData
        }
        
        public func toDictionary(signer: Signer?, peerSigner: Signer?) -> [String: String]? {
            if let signer = signer, let peerSigner = peerSigner {
                if let personalDataAsBase64String = personalData.encrypt(signer: signer, peerSigner: peerSigner)?.base64String {
                    return [
                        "Destination": destination.toString,
                        "PublicKeyForEncryption": publicKeyForEncryption?.publicKeyForEncryptionToString ?? "",
                        "CombinedSealedBox": combinedSealedBox, //image binary or zip file
                        "Description": description,
                        "PersonalData": personalDataAsBase64String,
                    ]
                }
            } else {
                return [
                    "Destination": destination.toString,
                    "PublicKeyForEncryption": publicKeyForEncryption?.publicKeyForEncryptionToString ?? "",
                    "CombinedSealedBox": combinedSealedBox, //image binary or zip file
                    "Description": description,
                    "PersonalData": "",
                ]
            }
            return nil
        }
        public func toJsonString(signer: Signer?, peerSigner: Signer?) -> String? {
            if let signer = signer, let peerSigner = peerSigner {
                Log()
                if let personalDataAsJsonString = self.personalData.encrypt(signer: signer, peerSigner: peerSigner)?.base64String {
                    Log()
                    return [
                        "Destination": destination.toString,
                        "PublicKeyForEncryption": publicKeyForEncryption?.publicKeyForEncryptionToString ?? "",
                        "CombinedSealedBox": combinedSealedBox, //image binary or zip file
                        "Description": description,
                        "PersonalData": personalDataAsJsonString,
                    ].dictionaryToJsonString
                }
            } else {
                Log()
                return [
                    "Destination": destination.toString,
                    "PublicKeyForEncryption": publicKeyForEncryption?.publicKeyForEncryptionToString ?? "",
                    "CombinedSealedBox": combinedSealedBox, //image binary or zip file
                    "Description": description,
                    "PersonalData": "",
                ].dictionaryToJsonString
            }
            return nil
        }
    }
    
    /*
     Should encrypt this Data as Publish.
     */
    public struct PersonalData {
        public let name: String    // self.realName, "
        public let birth: String   // self.realBirth.toUTCString, "
        public let place: String   // self.quadkeyString, "
        public let bornPlace: String   // self.bornedquadkeyString, "
        public let phone: String   // self.realTelephoneNumber
        public init(name: String, birth: String, place: String, bornPlace: String, phone: String) {
            self.name = name
            self.birth = birth
            self.place = place
            self.bornPlace = bornPlace
            self.phone = phone
        }
        public init?(dictionary: [String: String]) {
            if let name = dictionary["name"], let birth = dictionary["birth"], let place = dictionary["place"], let bornPlace = dictionary["bornPlace"], let phone = dictionary["phone"] {
                self.init(name: name, birth: birth, place: place, bornPlace: bornPlace, phone: phone)
            }
            self.init(name: "", birth: "", place: "", bornPlace: "", phone: "")
        }
        
        public static let null = PersonalData(name: "", birth: "", place: "", bornPlace: "", phone: "")

        public var dictionary: [String: String] {
            ["name": self.name, "birth": self.birth, "place": self.place, "bornPlace": self.bornPlace, "phone": self.phone]
        }
        
        public func encrypt(signer: Signer, peerSigner: Signer) -> Data? {
            //encrypt personal data
            if let peerPublicKeyForEncryption = peerSigner.publicKeyForEncryption, let personalDataAsData = self.dictionary.dictionaryToJsonString?.utf8DecodedData {
                if let personalDataAsEncrypted = signer.encrypt(message: personalDataAsData, peerPublicKeyForEncryption: peerPublicKeyForEncryption),
                    let personalDatacAsCombinedSealedBox = personalDataAsEncrypted.combined {
                    return personalDatacAsCombinedSealedBox
                }
            }
            return nil
        }
    }
    
    public func construct(destination: OverlayNetworkAddressAsHexString, publicKeyForEncryption: PublicKeyForEncryption?, combinedSealedBox: String, description: String, attachedFileType: String, personalData: PersonalData) -> Object {
        Object(destination: destination, publicKeyForEncryption: publicKeyForEncryption, combinedSealedBox: combinedSealedBox, description: description, attachedFileType: attachedFileType, personalData: personalData)
    }
    public func construct(json: String) -> Object {
        if let jsonAsDictionary = json.jsonToDictionary {
            if let destination = jsonAsDictionary["Destination"],
                let publicKeyForEncryptionString = jsonAsDictionary["PublicKeyForEncryption"],
               let publicKeyForEncryption = publicKeyForEncryptionString.base64DecodedData,
                let combinedSealedBox = jsonAsDictionary["CombinedSealedBox"],
                let description = jsonAsDictionary["Description"],
                let personalDataString = jsonAsDictionary["PersonalData"],
                let attachedFileType = jsonAsDictionary["attachedFileType"],
                let personalDictionary = personalDataString.jsonToDictionary, let name = personalDictionary["name"],
                let birth = personalDictionary["birth"],
                let place = personalDictionary["place"],
                let bornPlace = personalDictionary["bornPlace"],
                let phone = personalDictionary["phone"] {
                let personalData = PersonalData(name: name, birth: birth, place: place, bornPlace: bornPlace, phone: phone)
                return Object(destination: destination, publicKeyForEncryption: publicKeyForEncryption, combinedSealedBox: combinedSealedBox, description: description, attachedFileType: attachedFileType, personalData: personalData)
            }
        }
        return Object(destination: "")  //null
    }

    public func object(content: String) -> ClaimObject? {
        Log(content)
        guard let jsonAsDictionary = content.jsonToDictionary else {
            Log()
            return nil
        }
        Log()
        switch self {
        case .findTaker:
            if let destination = jsonAsDictionary["Destination"],
               let publicKeyForEncryptionString = jsonAsDictionary["PublicKeyForEncryption"],
               let publicKeyForEncryption = publicKeyForEncryptionString.base64DecodedData {
                Log()
                return Object(destination: destination, publicKeyForEncryption: publicKeyForEncryption)
            }
        case .findTakerReply:
            if let destination = jsonAsDictionary["Destination"],
               let publicKeyForEncryptionString = jsonAsDictionary["PublicKeyForEncryption"],
               let publicKeyForEncryption = publicKeyForEncryptionString.base64DecodedData,
               let description = jsonAsDictionary["Description"] {
                return Object(destination: destination, publicKeyForEncryption: publicKeyForEncryption, description: description)
            }
        case .askForTaker:
            if let destination = jsonAsDictionary["Destination"],
                let publicKeyForEncryptionString = jsonAsDictionary["PublicKeyForEncryption"],
                let publicKeyForEncryption = publicKeyForEncryptionString.base64DecodedData,
                let combinedSealedBox = jsonAsDictionary["CombinedSealedBox"],
                let description = jsonAsDictionary["Description"],
                let attachedFileType = jsonAsDictionary["attachedFileType"],
                let personalDataString = jsonAsDictionary["PersonalData"],
                let personalDictionary = personalDataString.jsonToDictionary,
                let name = personalDictionary["name"],
                let birth = personalDictionary["birth"],
                let place = personalDictionary["place"],
                let bornPlace = personalDictionary["bornPlace"],
                let phone = personalDictionary["phone"] {
                let personalData = PersonalData(name: name, birth: birth, place: place, bornPlace: bornPlace, phone: phone)
                return Object(destination: destination, publicKeyForEncryption: publicKeyForEncryption, combinedSealedBox: combinedSealedBox, description: description, attachedFileType: attachedFileType, personalData: personalData)
            }
        case .askForTakerReply:
            if let destination = jsonAsDictionary["Destination"],
                let publicKeyForEncryptionString = jsonAsDictionary["PublicKeyForEncryption"],
                let publicKeyForEncryption = publicKeyForEncryptionString.base64DecodedData,
                let combinedSealedBox = jsonAsDictionary["CombinedSealedBox"],
                let description = jsonAsDictionary["Description"] {
                return Object(destination: destination, publicKeyForEncryption: publicKeyForEncryption, combinedSealedBox: combinedSealedBox, description: description)
            }
        case .born:
            if let destination = jsonAsDictionary["Destination"],
                let publicKeyForEncryptionString = jsonAsDictionary["PublicKeyForEncryption"],
                let publicKeyForEncryption = publicKeyForEncryptionString.base64DecodedData,
                let combinedSealedBox = jsonAsDictionary["CombinedSealedBox"],
                let description = jsonAsDictionary["Description"] {
                return Object(destination: destination, publicKeyForEncryption: publicKeyForEncryption, combinedSealedBox: combinedSealedBox, description: description)
            }
        default:
            return nil
        }
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
    
    public static let null = ClaimOnPerson(rawValue: "")    //return nil

    /*
     Like Electrical Mail.
     
     To:        Destination
     Title:     (n/a)
     Body:      Description
     File:      combinedSealedBox
     CryptKey:  PublicKeyForEncryption
     Mail Type: Claim
     */
    public func body(destinationDhtAddress: String, description: String, signer: Signer, combinedSealedBox: Data? = nil, attachedFileType: FileType? = nil, personalDataAsEncrypted: Data?) -> [String: String]? {
        switch self {
        case .findTaker:
            return [
                "Destination": ClaimOnPerson.destinationBroadCast,
                "Claim": ClaimOnPerson.findTaker.rawValue,
            ]
        case .findTakerReply:
            return [
                "Destination": "destinationDhtAddress",
                "Claim": ClaimOnPerson.findTaker.replyClaim,
                "PublicKeyForEncryption": "publicKeyAsBase64String",
                "Description": "description",
            ]
        case .askForTaker:
            return [
                "Destination": "destinationDhtAddress",
                "Claim": ClaimOnPerson.askForTaker.rawValue,
                "PublicKeyForEncryption": "publicKeyAsBase64String",
                "CombinedSealedBox": "combinedSealedBox.base64String", //image binary or zip file
                "Description": "description",
                "PersonalData": "personalDataAsBase64String",
            ]
        case .askForTakerReply:
            return [
                "Destination": "destinationDhtAddress",
                "Claim": ClaimOnPerson.askForTaker.replyClaim,
                "PublicKeyForEncryption": "publicKeyAsBase64String",
                "CombinedSealedBox": "combinedSealedBox.base64String", //image binary or zip file
                "Description": "description",
            ]
        case .born:
            return [
                "Destination": "destinationDhtAddress",
                "Claim": ClaimOnPerson.born.rawValue,
                "PublicKeyForEncryption": "publicKeyAsBase64String",
                "CombinedSealedBox": "combinedSealedBox.base64String", //image binary or zip file
                "Description": "description",
            ]

        default:
            return nil
        }
    }
    
    public func replyBody(destinationDhtAddress: OverlayNetworkAddressAsHexString, description: String, signer: Signer, combinedSealedBox: Data? = nil, attachedFileType: FileType? = nil, personalDataAsEncrypted: Data?) -> [String: String]? {
        Log()
        guard let publicKeyAsBase64String = signer.publicKeyForEncryption?.rawRepresentation.base64String else {
            return nil
        }
        switch self {
        case .findTaker:
            return [
                "Destination": destinationDhtAddress.toString,
                "Claim": self.replyClaim,   //Put Hand Up as Taker Candidate
                "PublicKeyForEncryption": publicKeyAsBase64String,
                "Description": description,
            ]
        case .findTakerReply:
            guard let personalDataAsBase64String = personalDataAsEncrypted?.base64String else {
                return nil
            }
            return [
                "Destination": destinationDhtAddress.toString,
                "Claim": ClaimOnPerson.askForTaker.rawValue,    //Ask for Taker
                "PublicKeyForEncryption": publicKeyAsBase64String,
                "CombinedSealedBox": combinedSealedBox?.base64String ?? "", //image binary or zip file
                "attachedFileType": attachedFileType?.rawValue ?? "",
                "Description": description,
                "PersonalData": personalDataAsBase64String,
            ]
        case .askForTaker:
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
    
    public func reply(to destinationDhtAddress: OverlayNetworkAddressAsHexString, description: String, node: Node, combinedSealedBox: Data?, attachedFileType: FileType?, personalData: PersonalData?, book: Book, peerSigner: Signer) {
        guard let signer = node.signer(), let publicKeyForEncryptionAsData = signer.publicKeyForEncryption?.rawRepresentation else {
            return
        }
        
        let claimObject = self.construct(destination: destinationDhtAddress, publicKeyForEncryption: publicKeyForEncryptionAsData, combinedSealedBox: combinedSealedBox?.base64String ?? "", description: description, attachedFileType: attachedFileType?.rawValue ?? "", personalData: personalData ?? PersonalData.null)
        if let publicKeyAsData = signer.publicKeyAsData {
            Log()
            //Send Reply mail
            if let replyClaim = ClaimOnPerson(rawValue: self.replyClaim),
                var transaction = TransactionType.person.construct(claim: replyClaim, claimObject: claimObject, makerDhtAddressAsHexString: destinationDhtAddress, publicKey: publicKeyAsData, book: book, signer: signer, peerSigner: peerSigner) {
                transaction.send(node: node, signer: signer)
            }
        }
    }
}

public extension Person {
    var transactionIdPrefix: String {
        return "PS"
    }
    var type: TransactionType {
        get {
            return .person
        }
        set {
        }
    }
    
    /*
     Birth Transactionの二重チェック
     
     ＜重複チェック方法＞
     cf.実在証明
     身元保証書Transaction（Taker身元保証人が署名した３情報）があること
     身元保証書の記載内容（氏名、住所等）でCached Blocksを検索して重複がないこと
         住所は広めの範囲（文字数を少なくして前方一致）のQuadKeyで検索する
  
     氏名and生年月日andデバイス電話番号でCached Blocksを検索する
     Takerの行動履歴確認
     Takerの署名が正しいか
     Takerは{1.5}人までのBirth署名ができる（これについては、blocksの普及速度に関係する。）
     ３等身以内のTakerは協力できない。
     */
    func duplicatedPerson(hashedName: String?, hashedBirth: String?, hashedPhone: String?) -> Bool {
        guard let hashedName = hashedName, let hashedBirth = hashedBirth, let hashedPhone = hashedPhone else {
            return false
        }
        var matchedSamePerson = false
        for block in self.book.blocks {
            Log()
            for transaction in block.transactions {
                Log(transaction.jsonString)
                if transaction.type == .person {
                    //It's Person transaction.
                    if let claimString = transaction.claim.rawValue {
                        if let claimObject = transaction.claimObject as? ClaimOnPerson.Object {
                            if claimObject.personalData.name == hashedName {
                                if claimObject.personalData.birth == hashedBirth {
                                    //There is same Person already.
                                    matchedSamePerson = true
                                    break
                                }
                            }
                            if claimObject.personalData.phone == hashedPhone {
                                //There is same Person already.
                                matchedSamePerson = true
                                break
                            }
                        }
                    }
                }
            }
            if matchedSamePerson {
                break
            }
        }
        return matchedSamePerson
    }
}

/*
 Person(Transaction Sub class)
 */
public protocol Person: Transaction {
    /*
     BasicIncome 定期給付金
         すべてのPersonに年１回50BK
     */
    mutating func addBasicIncomeAtborn(to destinationDhtAddress: OverlayNetworkAddressAsHexString)

    /*
        Birth       出生届
            自然人が一人１回だけBirthできる
            １８歳以上の成人のみBirth＆Transactionできる（未成年は利用できない）
            自分自身をBirthする
                身元保証人(Taker)１名の個人情報への署名が必要

            Json     トランザクションの内容
                ex. { transactionId: xxx, date:yyyymmdd hhmmss.ss, maker: xxx, from: xxx, to: xxx, amount: xxx, unit: xxx, rentTime: yyyymmdd hhmm }

            ＜Birthの流れ＞
            （Birth）Birth希望を周知する
            ↓
            （Birth）SMS、Eメール、チャットでBirthに添付する実在証明を得るために、Takerに個人情報を送付する
            ↓
            （Taker）秘密鍵で個人情報「住所・氏名・生年月日・電話番号」に署名（Hash->ECDSA256->Base64）して返信する
            ↓
            （Birth）Person - Birthする
     */
    mutating func addBornFeeToOwn()

    /*
        MoveIn      アプリケーションへの転入届
            Json    トランザクションの内容
                ex. { transactionId: xxx, date:yyyymmdd hhmmss.ss, maker: xxx, from: xxx, body: ID personの公開鍵で暗号した本人のデータ（名前、住所、写真、電話番号、スマホID） }
            *本人存在確認を行う
                MoveIn 時に、Fact(アプリケーションOwner)には個人情報が開示されるのでFactが実在確認を行う
            アプリケーション登録したオーナーの公開鍵は公開されている
            ↓
            （利用者）Birth時に個人情報（Hash&秘密鍵でEncrypt&Base64）をトランザクションに登録
            ↓
            （利用者）利用者の公開鍵をアプリケーションOwnerにOwnerの公開鍵で暗号してMailする
            ↓
            （Owner）Person - Validateする
            ↓
            （Owner）Person - Authorizeする
      */
    func moveIn()
     
     /*

        MoveOut     アプリケーションからの転出届
            Json    トランザクションの内容
                ex. { transactionId: xxx, date:yyyymmdd hhmmss.ss, maker: xxx, from: xxx, body: ID personの公開鍵で暗号した本人確認データ（写真） }
     */
    func moveOut()
    
    /*
        Validate    利用者の本人確認をする
            Birth時の個人情報を利用者からMailされた公開鍵で復号してチェックする
            [チェック方法]
            （Oracle）SMSなどでパスコードを送る
            ↓
            （Oracle）システムでチェック
            ↓
            チェック結果が存在しないあるいは不正がある場合
     */
//    func validate()
    
    /*

        Authorize   Fact OwnerがMoveInを許可する

     */
    func authorize()
    
}

public struct ImplementedPerson: Person {
    public var claim: any Claim
    
    public static func == (lhs: ImplementedPerson, rhs: ImplementedPerson) -> Bool {
        guard let lhsTransactionId = lhs.transactionId, let rhsTransactionId = rhs.transactionId else {
            return false
        }
        return lhsTransactionId.equal(rhsTransactionId)
    }
    
    public var debitOnLeft: BK = Decimal.zero
    public var withdrawalDhtAddressOnLeft: OverlayNetworkAddressAsHexString = ""
    public var creditOnRight: BK = Decimal.zero
    public var depositDhtAddressOnRight: OverlayNetworkAddressAsHexString = ""
    public var feeForBooker: BK = TransactionType.person.fee()

    public func isMatch<ArgumentA, ArgumentB>(type: TransactionType, claim: ArgumentA?, dhtAddressAsHexString: ArgumentB?) -> Bool {
        guard type == .person else {
            Log()
            return false
        }
        Log()
        /*
         Check Parameter Type.
         */
        var claimOn: ClaimOnPerson?
        var dhtAddressAsHexStringString: String?
        if claim == nil {
            if let dhtAddressAsHexString = dhtAddressAsHexString as? String {
                dhtAddressAsHexStringString = dhtAddressAsHexString
            } else {
                //Match all Mail Transactions.
                return true
            }
        } else {
            if let claim = claim as? ClaimOnPerson {
                Log()
                claimOn = claim
                return false
            }
        }
        
        let transactionAsDictionary = self.contentAsDictionary
        let destination = transactionAsDictionary["Destination"] ?? ""
        Log("\(self.claim.rawValue) : \(claimOn?.rawValue)")
        guard let claimRawValue = self.claim.rawValue, claimRawValue != claimOn?.rawValue else {
            Log()
            return false
        }
        Log(destination)
        if destination == ClaimOnPerson.destinationBroadCast || destination == dhtAddressAsHexStringString {
            Log()
            return true
        }
        Log()
        return false
    }

    public mutating func addBasicIncome(to destinationDhtAddress: OverlayNetworkAddressAsHexString) {
        Log()
        //Pull out (Withdraw) from Account
        self.debitOnLeft = Work.basicincomeMonthly.income()
        self.withdrawalDhtAddressOnLeft = Signer.moneySupplyUnMoverAccount  //Account for detect Total Money Supply

        //Transfer (Deposit) to Account
        self.creditOnRight = Work.basicincomeMonthly.income()
        self.depositDhtAddressOnRight = destinationDhtAddress
    }
    
    public mutating func addBasicIncomeAtborn(to destinationDhtAddress: OverlayNetworkAddressAsHexString) {
        Log()
        //Pull out (Withdraw) from Account
        self.debitOnLeft = Work.basicincomeAtBorn.income()
        self.withdrawalDhtAddressOnLeft = Signer.moneySupplyUnMoverAccount
        //Transfer (Deposit) to Account
        self.creditOnRight = Work.basicincomeAtBorn.income()
        self.depositDhtAddressOnRight = destinationDhtAddress
    }
    
    public mutating func addBornFeeToOwn() {
        Log()
        //Pull out (Withdraw) from Account
        self.debitOnLeft = Work.birthCertificate.income()
        self.withdrawalDhtAddressOnLeft = Signer.moneySupplyUnMoverAccount
        //Transfer (Deposit) to Account
        self.creditOnRight = Work.birthCertificate.income()
        self.depositDhtAddressOnRight = self.makerDhtAddressAsHexString
    }

    public func moveIn() {
        Log()
    }
    
    public func moveOut() {
        Log()
    }
    
    public func authorize() {
        Log()
    }
    
    public init() {
        Log()
        self.date = nil
        self.transactionId = nil
        self.claim = ClaimOnPerson.findTaker
        self.makerDhtAddressAsHexString = ""
        self.claimObject = ClaimOnPerson.Object(destination: "")
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
    
    public var contentAsDictionary: [String: String] {
        if let contentAsJsonString = self.claimObject.toJsonString(signer: self.signer, peerSigner: self.peerSigner) {    //base64 →Data →utf8
            Log()
            Log(contentAsJsonString)
            if let contentAsDictionary = contentAsJsonString.jsonToDictionary {
                return contentAsDictionary
            }
        }
        return [:]
    }

    public var makerDhtAddressAsHexString: OverlayNetworkAddressAsHexString
    
    public var claimObject: ClaimObject
    
    public var signature: Signature?
    public var publicKey: PublicKey?
    public var book: Book

    public var transactionId: TransactionIdentification?
    public var date: Date?
    public var signer: Signer
    public var peerSigner: Signer?
}
