//
//  Transaction.swift
//  blocks
//
//  Created by よういち on 2020/06/06.
//  Copyright © 2020 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

/*
 Transaction    トランザクション
 */
import Foundation
import CryptoKit
import overlayNetwork

public enum TransactionType: String {
    case pay
    case mail
    case fact
    case person

    public func fee() -> BK {
        switch self {
        case .pay:
            return Decimal(1)
        case .mail:
            return Decimal(1)
        case .fact:
            return Decimal(1)
        case .person:
            return Decimal(0)    //birthなど
        }
    }
    
    public func construct(claim: any Claim, claimObject: any ClaimObject, makerDhtAddressAsHexString: OverlayNetworkAddressAsHexString, publicKey: PublicKey?, signature: Signature? = nil, book: Book, signer: Signer, peerSigner: Signer? = nil, transactionId: TransactionIdentification? = nil, date: Date? = Date.now, debitOnLeft: BK = Decimal.zero, creditOnRight: BK = Decimal.zero, withdrawalDhtAddressOnLeft: String = "", depositDhtAddressOnRight: String = "") -> (any Transaction)? {
        Log(self.rawValue)
        var transaction: (any Transaction)?
        guard let publicKey = publicKey else {
            return transaction
        }
        switch self {
        case .pay:
            transaction = Pay(claim: claim, claimObject: claimObject, makerDhtAddressAsHexString: makerDhtAddressAsHexString, publicKey: publicKey, signature: signature, book: book, signer: signer, peerSigner: peerSigner, transactionId: transactionId, date: date, debitOnLeft: debitOnLeft, creditOnRight: creditOnRight, withdrawalDhtAddressOnLeft: withdrawalDhtAddressOnLeft, depositDhtAddressOnRight: depositDhtAddressOnRight)
        case .mail:
            transaction = Mail(claim: claim, claimObject: claimObject, makerDhtAddressAsHexString: makerDhtAddressAsHexString, publicKey: publicKey, signature: signature, book: book, signer: signer, peerSigner: peerSigner, transactionId: transactionId, date: date, debitOnLeft: debitOnLeft, creditOnRight: creditOnRight, withdrawalDhtAddressOnLeft: withdrawalDhtAddressOnLeft, depositDhtAddressOnRight: depositDhtAddressOnRight)
        case .fact:
            transaction = Fact(claim: claim, claimObject: claimObject, makerDhtAddressAsHexString: makerDhtAddressAsHexString, publicKey: publicKey, signature: signature, book: book, signer: signer, peerSigner: peerSigner, transactionId: transactionId, date: date, debitOnLeft: debitOnLeft, creditOnRight: creditOnRight, withdrawalDhtAddressOnLeft: withdrawalDhtAddressOnLeft, depositDhtAddressOnRight: depositDhtAddressOnRight)
        case .person:
            transaction = ImplementedPerson(claim: claim, claimObject: claimObject, makerDhtAddressAsHexString: makerDhtAddressAsHexString, publicKey: publicKey, signature: signature, book: book, signer: signer, peerSigner: peerSigner, transactionId: transactionId, date: date, debitOnLeft: debitOnLeft, creditOnRight: creditOnRight, withdrawalDhtAddressOnLeft: withdrawalDhtAddressOnLeft, depositDhtAddressOnRight: depositDhtAddressOnRight)
        default:
            break
        }
        return transaction
    }
    
    public func construct(rawValue: String) -> (any Claim)? {
        Log(self.rawValue)
        var claim: (any Claim)?
        switch self {
        case .pay:
            claim = ClaimOnPay(rawValue: rawValue)
        case .mail:
            claim = ClaimOnMail(rawValue: rawValue)
        case .fact:
            claim = ClaimOnFact(rawValue: rawValue)
        case .person:
            claim = ClaimOnPerson(rawValue: rawValue)
        default:
            break
        }
        return claim
    }
    
    public func constructClaim(rawValue: String) -> (any Claim)? {
        Log(self.rawValue)
        var claim: (any Claim)?
        switch self {
        case .pay:
            claim = ClaimOnPay(rawValue: rawValue)
        case .mail:
            claim = ClaimOnMail(rawValue: rawValue)
        case .fact:
            claim = ClaimOnFact(rawValue: rawValue)
        case .person:
            claim = ClaimOnPerson(rawValue: rawValue)
        default:
            break
        }
        return claim
    }
    
    public func reply(to destinationDhtAddress: OverlayNetworkAddressAsHexString, claim: (any Claim)?, description: String, node: Node, combinedSealedBox: Data?, attachedFileType: FileType?, personalData: ClaimOnPerson.PersonalData?, book: Book, peerSigner: Signer) {
       switch self {
       case .pay:
           (claim as? ClaimOnPay)?.reply(to: destinationDhtAddress, description: description, node: node, combinedSealedBox: combinedSealedBox, attachedFileType: attachedFileType, personalData: personalData, book: book, peerSigner: peerSigner)
       case .mail:
           (claim as? ClaimOnMail)?.reply(to: destinationDhtAddress, description: description, node: node, combinedSealedBox: combinedSealedBox, attachedFileType: attachedFileType, personalData: personalData, book: book, peerSigner: peerSigner)
       case .fact:
           (claim as? ClaimOnFact)?.reply(to: destinationDhtAddress, description: description, node: node, combinedSealedBox: combinedSealedBox, attachedFileType: attachedFileType, personalData: personalData, book: book, peerSigner: peerSigner)
       case .person:
           (claim as? ClaimOnPerson)?.reply(to: destinationDhtAddress, description: description, node: node, combinedSealedBox: combinedSealedBox, attachedFileType: attachedFileType, personalData: personalData, book: book, peerSigner: peerSigner)
       default:
           return
       }
    }
    
}

public extension Transaction {
    var transactionIdPrefix: String {
        "BK"
    }
    
    /*
     Paper:
     digitally signing a hash of the previous transaction and the public key of the next owner and adding these to the end of the coin.
     */
    var hashOfPreviousTransaction: HashedString {
        ""
    }
    var publicKeyOfNextOwner: PublicKey {
        Data.DataNull
    }
    //#あと
        
    var utcTimeString: String {
        if let timeString = self.date?.utcTimeString {
            return timeString
        }
        return ""
    }
    
    var useAsHash: String {
        get {
//            Log(self.signature?.toString)
//            Log(self.date?.utcTimeString)
//            Log(self.claimObject.toJsonString(signer: self.signer, peerSigner: self.peerSigner))
//            Log(self.claim.rawValue)
            if let dateString = self.date?.utcTimeString, let claimObject = self.claimObject.toJsonString(signer: self.signer, peerSigner: self.peerSigner), let claim = self.claim.rawValue {
                var json = """
{"date":"\(dateString)","type":"\(self.type.rawValue)","makerDhtAddressAsHexString":"\(self.makerDhtAddressAsHexString)","publicKey":"\(self.publicKey?.publicKeyToString ?? "")","claim":"\(claim)","claimObject":\(claimObject)"}
"""
                Log(json)
                //remove \n
                json = json.removeNewLineChars
                return json
            }
            return ""
        }
    }
    
    //Publish時などに使う
    //transaction property items without makerdhtaddress, publickey
    var useAsOperands: String {
        get {
            if let signature = self.signature?.toString, let transactionId = self.transactionId, let dateString = self.date?.utcTimeString, let claimObject = self.claimObject.toJsonString(signer: self.signer, peerSigner: self.peerSigner), let claim = self.claim.rawValue {
                var json = """
{"transactionId":"\(transactionId)","date":"\(dateString)","type":"\(self.type.rawValue)","claim":"\(claim)","claimObject":\(claimObject),"signature":"\(signature)"}
"""
                Log(json)
                //remove \n
                json = json.removeNewLineChars
                return json
            }
            return ""
        }
    }

    //All transaction property items
    var jsonString: String {
        get {
            if let signature = self.signature?.toString, let transactionId = self.transactionId, let dateString = self.date?.utcTimeString, let claimObject = self.claimObject.toJsonString(signer: self.signer, peerSigner: self.peerSigner), let claim = self.claim.rawValue {
                var json = """
{"transactionId":"\(transactionId)","date":"\(dateString)","type":"\(self.type.rawValue)","makerDhtAddressAsHexString":"\(self.makerDhtAddressAsHexString)","publicKey":"\(self.publicKey?.publicKeyToString ?? "")","claim":"\(claim)","claimObject":\(claimObject),"signature":"\(signature)"}
"""
                Log(json)
                //remove \n
                json = json.removeNewLineChars
                return json
            }
            return ""
        }
    }
    
    var contentAsDictionary: [String: String] {
        if let contentAsJsonString = self.claimObject.toJsonString(signer: self.signer, peerSigner: self.peerSigner) {
            Log()
            Log(contentAsJsonString)
            if let contentAsDictionary = contentAsJsonString.jsonToDictionary {
                return contentAsDictionary
            }
        }
        return [:]
    }

    /*
     Publish     Transactionを発行する
     */
    func publish(on node: Node, with signer: Signer) {
        Log()
        /*
         Known Nodeに送信する
         
         Transactionを known node にブロードキャストする（Mail）
         自分が知っているnodeに対して block を送信する
         known node:
         predecessor, successor, babysitter(arbitrary node)
         */
        Log(self.signature?.toString)   //←Transaction#signature これがnilのため実行されない #now
        Log(signer.base64EncodedPublicKeyForSignatureString)
        let signatureString = self.signature?.toString
        Log(signatureString)
        let base64 = signer.base64EncodedPublicKeyForSignatureString
        Log(base64)
        let transactionId = self.transactionId
        Log(transactionId)
        let dateString = self.date?.utcTimeString
        Log(dateString)
        
        guard let signatureString = self.signature?.toString, signer.base64EncodedPublicKeyForSignatureString != "", let transactionId = self.transactionId, let dateString = self.date?.utcTimeString else {
            Log("Void Signature cause Can NOT Publish Transaction.")
            return
        }
        Log()
        //Common Column
        var operands = [signer.base64EncodedPublicKeyForSignatureString, self.makerDhtAddressAsHexString.toString, "1"]
        //By Transaction Column
        operands += [self.useAsOperands]
        Log(operands)
        if let predecessorOverlayNetworkAddress = node.predecessor?.dhtAddressAsHexString {
            Command.publishTransaction.send(node: node, to: predecessorOverlayNetworkAddress, operands: operands) { string in
                Log(string)
            }
        }
        if let successorOverlayNetworkAddress = node.successor?.dhtAddressAsHexString {
            Command.publishTransaction.send(node: node, to: successorOverlayNetworkAddress, operands: operands) { string in
                Log(string)
            }
        }
        if let babysitterOverlayNetworkAddress = node.babysitterNode?.dhtAddressAsHexString {
            Command.publishTransaction.send(node: node, to: babysitterOverlayNetworkAddress, operands: operands) { string in
                Log(string)
            }
        }
    }
    
    /*
     *Validate    Blockにブッキングするときにトランザクションの有効性をチェックする
         makerのamountが送金額以上かチェック
         makerがアプリケーション利用者か？
             利用者登録必要か？
         Block内Transactionの妥当性
         Book時には署名の確認のみ　←アカウントの保証はできる
         ３親等以内への（BirthからTaker、TakerからBirth）送金は無効とする
     
     #あと content 以外も著名対象とする
     
     Paper:
     5) ノードは、ブロック内のすべてのトランザクションが有効で、まだ使用されていない場合にのみブロックを受け入れます。
     */
    func validate(chainable: Book.ChainableResult = .chainableBlock, branchChainHash: HashedString?, indexInBranchChain: Int?) -> Bool {
        Log()
        guard let contentData = self.claimObject.toJsonString(signer: self.signer, peerSigner: self.peerSigner)?.utf8DecodedData, let contentHashedData = contentData.hashedData?.toData, let signature = self.signature else {
            Log("transaction signature false")
            return false
        }
        Log("SIGN#++")
        Log("raw data: \(self.claimObject.toJsonString(signer: self.signer, peerSigner: self.peerSigner))")
        Log("data: \(contentData.base64String)")
        Log("hashed data: \(contentHashedData.base64String)")
        Log("signature: \(signature.toString)")
        do {
            guard try self.verify(data: contentHashedData, signature: signature, signer: self.signer) else {
                Log("transaction verify false")
                return false
            }
            
            /*
             Check Duplicate Birth as same Person.
             Only for Person transaction.
             
             Check Transactions Limited by Claim.
             */
            if self.type == .person {
                Log(self.claim.rawValue)
                if let claimObject = self.claimObject as? ClaimOnPerson.Object, let personTransaction = self as? ImplementedPerson {
                    if personTransaction.duplicatedPerson(chainable: chainable, branchChainHash: branchChainHash, indexInBranchChain: indexInBranchChain) {
                        //Duplicated Person
                        Log("Duplicate Birth as same Person.")
                        return false
                    }
                }
            }
            
            /*
             Check balance for debit/credit in Transaction.
             */
            if !self.debitOnLeft.equal(self.creditOnRight) {
                Log("No Match Balance for debit/credit in Transaction")
                return false
            }

            /*
             Check Number of Digits Under Regulated Decimal Point.
             */
            guard self.debitOnLeft.validBKDigitsOfFraction(Decimal.validBKDigitsOfFraction) else {
                Log("Invalid Digits in DebitOnLeft. \(self.debitOnLeft)")
                return false
            }
            guard self.creditOnRight.validBKDigitsOfFraction(Decimal.validBKDigitsOfFraction) else {
                Log("Invalid Digits in CreditOnRight. \(self.creditOnRight)")
                return false
            }
            Log("\(self.debitOnLeft) \(self.creditOnRight)")
            Log(Decimal.maxBKValue)
            /*
             Check Whether Under Transaction#maxValue
             */
            //Decimal.max以下かチェックする
            guard self.debitOnLeft.asDecimal <= Decimal.maxBKValue.asDecimal else {
                Log("Over Maximum Digit DebitOnLeft.")
                return false
            }
            guard self.creditOnRight.asDecimal <= Decimal.maxBKValue.asDecimal else {
                Log("Over Maximum Digit CreditOnRight.")
                return false
            }

            /*
             Check Account Balance.
             */
            //transactionの送金金額＋手数料　<= balance
            Log()
            let balancedAmount = self.book.balance(dhtAddressAsHexString: self.makerDhtAddressAsHexString)
            Log("\(self.debitOnLeft) + \(self.feeForBooker) <= \(balancedAmount)")
            guard self.debitOnLeft.asDecimal + self.feeForBooker.asDecimal <= balancedAmount.asDecimal else {
                //Short of balances.
                Log("Short of balances in Account.")
                return false
            }
        } catch {
            Log(error)
            return false
        }
        Log("transaction validate true")
        return true
    }
    
    /*
     Sign        署名する
         Hash
         Base64
         Encrypt(ECDSA 256) makerの公開鍵で暗号
     
     #あと content 以外も著名対象とする
     */
    mutating func sign(with signer: Signer) throws {
        Log()
        if let contentAsData = self.claimObject.toJsonString(signer: self.signer, peerSigner: self.peerSigner)?.utf8DecodedData, let contentHashedData = contentAsData.hashedData?.toData, let signature = try signer.sign(contentAsData: contentHashedData) {
            Log("SIGN#--")
            Log("raw data\(self.claimObject.toJsonString(signer: self.signer, peerSigner: self.peerSigner))")
            Log("data: \(contentAsData.base64String)")
            Log("hashed data: \(contentHashedData.base64String)")
            Log("signature: \(signature.toString)")
            Log("publicKey: \(signer.publicKeyForSignature?.rawRepresentation.base64String)")
            self.signature = signature
        }
    }
    
    /*
     署名、データ、公開鍵から次を確認する
        1)送信元が正しいか
        2)データが改変されていないか
     */
    func verify(data: Data, signature: Signature, signer: Signer) throws -> Bool {
        Log()
        Log("Verify Transaction.")
        Log(data.base64String)
        Log(signature.toString)
        Log(signer.publicKeyForSignature?.rawRepresentation.base64String)
        let verifySucceeded = try signer.verify(data: data, signature: signature)
        Log("Verify Transaction? \(verifySucceeded)")
        return verifySucceeded
    }
    
    /*
     Paper:
     ブロックのハッシュを壊すことなくこれを容易にするために、トランザクションはマークル ツリー [7][2][5]でハッシュ化され、ブロックのハッシュにはルートのみが含まれます。
     #now
     ↑
     block圧縮のため　マークルツリーにする
     */
    func hash(into hasher: inout Hasher) {
        return hasher.combine(transactionId?.transactionIdentificationToString)
    }

    /*
     署名を追加してから、Publishする
     
        ex.（Birth）SMS、Eメール、チャットでBirthに添付する実在証明を得るために、Takerに個人情報を送付する
     */
    mutating func send(node: Node, signer: Signer) {
        Log()
        /*
         As Transaction Have Not Signature yet (Unsigned), Sign it.
         */
        if self.signature == nil {
            Log()
            do {
                if let _ = signer.privateKeyForSignature {
                    Log(signer.privateKeyForSignature?.rawRepresentation.base64String)
                    try sign(with: signer)
                }
            } catch {
                Log(error)
            }
        }
        Log()
        publish(on: node, with: signer)
    }

    func filter(dhtAddressAsHexString: OverlayNetworkAddressAsHexString) -> (Bool, TransactionMatchType?) {
        Log()
        if self.withdrawalDhtAddressOnLeft.equal(dhtAddressAsHexString) && self.depositDhtAddressOnRight.equal(dhtAddressAsHexString) {
            Log("Match Debit & Credit.")
            return(true, .both)
        } else if self.withdrawalDhtAddressOnLeft.equal(dhtAddressAsHexString) {
            //Matched Withdrawal Account 引き落とし口座と一致
            Log("Match Debit. 引き落とし口座と一致")
            return (true, .left)
        } else if self.depositDhtAddressOnRight.equal(dhtAddressAsHexString) {
            //Matched Deposit Account 預け入れ口座と一致
            Log("Match Credit. 預け入れ口座と一致")
            return (true, .right)
        }
        
        return (false, nil)
    }

    static func == (lhs: any Transaction, rhs: any Transaction) -> Bool {
        guard let lhsTransactionId = lhs.transactionId, let rhsTransactionId = rhs.transactionId else {
            return false
        }
        return lhsTransactionId.equal(rhsTransactionId)
    }
}

public enum TransactionMatchType: String {
    case left   //Debit
    case right  //Credit
    case both   //Debit & Credit ←No Way. 通常はない
}

public protocol Transaction: Hashable {
    /*
     Hashable
     */
    func hash(into hasher: inout Hasher)

    /*
     Identifiable
     */
    static func == (lhs: any Transaction, rhs: any Transaction) -> Bool

    var date: Date? {
        get set
    }
    var transactionId: TransactionIdentification? {
        get set
    }
    var type: TransactionType { get set }
    var claim: any Claim { get set }
    var makerDhtAddressAsHexString: OverlayNetworkAddressAsHexString { get set }
    var claimObject: ClaimObject { get set }

    var signature: Signature? { get set }
    var publicKey: PublicKey? { get set }
    
    var signer: Signer { get set }
    var peerSigner: Signer? { get set }

    /*
     Transaction examples.
     
     Treat As Book for Bank.
     -----------------|-----------------
     Debit              Credit
     -----------------|-----------------

     
     Transfer (Transaction Fee, Withdrawal, Direct Deposit) transaction:
     -----------------|-----------------
     Debit Account      Credit Account
     1000               1000
     "8alduiLKJDB9883"  "eoKihAfoads83ioaoid"
     -----------------|-----------------

     
     Credit Creation (Booker Fee, Taker Fee, Basic Income) transaction: =Money Supply
     -----------------|-----------------
     Total Money Supply   Credit Account
     1000                 1000
     "-"                  "eoKihAfoads83ioaoid"
     -----------------|-----------------

     
     取引仕分け例
     
     銀行の複式簿記とするので、貸借記述が逆になる
     #帳簿記述方法
     
     借      貸
     debit  credit
     振り込みトランザクション:
     引き落とし口座        預け入れ口座
     1000               1000
     "8alduiLKJDB9883"  "eoKihAfoads83ioaoid"

     信用創造（預け入れ創造）／給付（返す必要なし）Credit Creationトランザクション:
     通貨供給量   預け入れ口座
     1000       1000
     "-"        "eoKihAfoads83ioaoid"
     */
    var book: Book { get set }
    
    /*
     -
     借方　Debit
     振り込み、引き落とし
     
     例）
     Mail) 切手手数料  Owner →Booker
     
     借      貸
     debit  credit
     振り込みトランザクション:     出金取引（送金、支払い）
     引き落とし口座    預け入れ口座
     1000           1000
     "8alduiLKJDB9883"  "eoKihAfoads83ioaoid"

     信用創造／給付（返す必要なし）トランザクション:
     withdrawalDhtAddressOnLeft: "-"　とする
     */
    var debitOnLeft: BK { get set }             //左側    debit　引き落とし額 =withdrawal    借方  debtor
    var withdrawalDhtAddressOnLeft: OverlayNetworkAddressAsHexString { get set }    //引き落とし口座
    
    /*
     +
     貸方 Credit
     信用創造（Booker手数料、Basic Income収入、Transaction取扱手数料、Taker手数料(Born)）Credit Creation

     例）
     Person) Taker手数料      信用創造  →Owner
     Person) BasicIncome    信用創造  →Birth依頼者
     
     信用創造／給付（返す必要なし）トランザクション:
     通貨供給量   預け入れ口座
     1000       1000
     "-"        "eoKihAfoads83ioaoid"
     */
    var creditOnRight: BK { get set }           //右側    credit  預け入れ額 =deposit   貸方  creditor
    var depositDhtAddressOnRight: OverlayNetworkAddressAsHexString { get set }       //預け入れ口座
    
    var feeForBooker: BK { get set }
    var utcTimeString: String {
        get
    }
    var useAsHash: String {
        get
    }
    var jsonString: String {
        get
    }
    var contentAsDictionary: [String: String] {
        get
    }
    
    init()
    init(claim: any Claim, claimObject: ClaimObject, makerDhtAddressAsHexString: OverlayNetworkAddressAsHexString, publicKey: PublicKey, signature: Signature?, book: Book, signer: Signer, peerSigner: Signer?, transactionId: TransactionIdentification?, date: Date?, debitOnLeft: BK, creditOnRight: BK, withdrawalDhtAddressOnLeft: String, depositDhtAddressOnRight: String)

    func isMatch<ArgumentA, ArgumentB>(type: TransactionType, claim: ArgumentA?, dhtAddressAsHexString: ArgumentB?) -> Bool
    mutating func send(node: Node, signer: Signer)
    func filter(dhtAddressAsHexString: OverlayNetworkAddressAsHexString) -> (Bool, TransactionMatchType?)
}
