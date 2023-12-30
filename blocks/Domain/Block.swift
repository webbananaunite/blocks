//
//  Block.swift
//  blocks
//
//  Created by よういち on 2020/06/11.
//  Copyright © 2020 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation
import overlayNetwork

/*
 Block          ブロック
 */
public struct Block {
    /*
     Paper:
     攻撃者が成功する確率
     
     #include <math.h>
    double AttackerSuccessProbability(double q, int z)
    {
        double p = 1.0 - q;
        double lambda = z * (q / p);
        double sum = 1.0;
        int i, k;
        for (k = 0; k <= z; k++)
        {
            double poisson = exp(-lambda);
            for (i = 1; i <= k; i++)
                poisson *= lambda / i;
            sum -= poisson * (1 - pow(q / p, z - k));
         }
         return sum;
     }
     */
    public static let maxTransactionsInABlock = 32  //Exclude Booker fee and (monthly, annual) known transaction Periodically  (ex. Basic income)
    
    var id: BlockIdentification
    private func setupId() -> BlockIdentification {
        /*
         block内Transactionすべての内容と現在時間をハッシュしてUniqueな文字列を生成する
         */
        let reducedTransactions = transactions.reduce("") {
            $1.useAsHash
        }
        let hashedString = reducedTransactions.hashedStringAsHex?.toString ?? ""
        return hashedString
    }
    
    var date: Date
    var transactions = [any Transaction]()
    /*
     Paper: block発行のincentive
     blockの最初のtransactionをblockメーカーのインセンティブにする
     CPU 時間と電力の代わりとしてのインセンティブ
     
     
     Paper: トランザクション取引手数料
     block内の各transactionの送金額(出力値)が、transaction ownerからの引き落とし額(入力値)より小さい場合、
        その差額はtransactionを含むblockのインセンティブとしてblock makerが受け取る
     #now

     
     Paper:
     発行額の上限を決める
     
     */
    mutating private func addfirstTransaction() {
        let signer = Signer(publicKeyAsData: self.publicKey, makerDhtAddressAsHexString: self.maker)
        if let incentiveTransaction = TransactionType.pay.construct(claim: ClaimOnPay.bookerFee, claimObject: ClaimOnMail.Object(destination: ""), makerDhtAddressAsHexString: self.maker, publicKey: nil, book: self.book, signer: signer, peerSigner: signer) {
            //#now 金額、publickeyなど
            self.transactions += [incentiveTransaction]
        }
    }
    
    /*
     Paper:
     blockの圧縮
     
     コインの最新のトランザクションが十分なブロックの下に埋もれると、それ以前の使用済みトランザクションはディスク領域を節約するために破棄されます。

     ブロックのハッシュを壊すことなくこれを容易にするために、トランザクションはマークル ツリー [7][2][5]でハッシュ化され、ブロックのハッシュにはルートのみが含まれます。

     古いブロックは、木の枝を切り落とすことで圧縮できます。 内部ハッシュを保存する必要はありません。
     #now あと
     */
    
    let maker: OverlayNetworkAddressAsHexString
    let publicKey: PublicKey
    public enum BlockType: String {
        case Block
    }
    let type = BlockType.Block
    var signature: Signature?
    let book: Book

    /*
     nonce
     
     ・nonceによるproof of work方法
        0になる先頭ビット数を定義して
        ex. 00000111111111111　←０が多くなるほど難しい
        ↓
        hash前の値(nonce)を求める
        ex.sha256
        ↓
        nonceをblockに追記
        ↓
        publish block
        ↓
        受け取ったら
        nonceをhashして確認する
        ↓
        nonce値がokならblock内容をチェックのうえbookする
        ↓
        長いblocksを採用する（正しいblockとみなす）

     0 bit数をどう決めるのか？
         ↑publish blockするときにblockに記入する？
     プルーフ・オブ・ワークの難易度は、1 時間あたりの平均ブロック数を対象とした移動平均によって決定されます。

     */
    var previousBlockHash: HashedString
    let previousBlockNonce: Nonce
    let previousBlockDifficulty: Difficulty
    let nextDifficulty: Difficulty
    
    public var nonce: Nonce
    /*
     Value Range is 0 - 512 (Nonce.bits)
     
     Default value is 16
     */
    public var difficultyAsNonceLeadingZeroLength: Difficulty

    private mutating func makeNonce() {
        Log()
        self.nonce = Nonce(preBlockNonce: self.previousBlockNonce)
    }
    
    var hashedString: HashedString? {
        if let contentAsUtf8String = self.content.utf8String {
            return contentAsUtf8String.hashedStringAsHex
        }
        return nil
    }
    
    //MARK: Constructor
    /*
     New         新規ブロック生成する
         Json    内容
             ex. { blockId: xxx, date:yyyymmdd hhmmss.ss, maker: xxx, transactions: [transactions] }
     */
    init?(date: String, maker: OverlayNetworkAddressAsHexString, signature: Signature, previousBlockHash: HashedString, previousBlockNonce: String, previousBlockDifficulty: Difficulty, nonceAsHex: String, publicKey: PublicKey, paddingZeroLength: Difficulty, book: Book, id: BlockIdentification? = nil) {
        Log()
        guard let previousNonceAsData = previousBlockNonce.hexadecimalDecodedData, let nonceAsData = nonceAsHex.hexadecimalDecodedData, let date = date.date else {
            return nil
        }
        let signatureAsData = signature.signatureToData
        self.date = date
        self.maker = maker
        self.signature = signatureAsData
        self.previousBlockHash = previousBlockHash
        self.previousBlockNonce = Nonce(paddingZeroLength: previousBlockDifficulty, nonceAsData: previousNonceAsData)//#now
        self.previousBlockDifficulty = previousBlockDifficulty
        /*
         Update Next Difficulty
         */
        self.nextDifficulty = book.makeNextDifficulty(blockDate: date)
        self.nonce = Nonce(paddingZeroLength: paddingZeroLength, nonceAsData: nonceAsData)
        self.difficultyAsNonceLeadingZeroLength = paddingZeroLength
        self.publicKey = publicKey
        self.book = book
        if let id = id {
            self.id = id
        } else {
            self.id = ""
            self.id = setupId()
        }
    }

    init?(maker: OverlayNetworkAddressAsHexString, signature: Signature? = nil, previousBlock: Block, nonceAsData: Data? = nil, publicKey: PublicKey, date: String, paddingZeroLengthForNonce: Difficulty, book: Book, id: BlockIdentification? = nil) {
        Log()
        guard let previousBlockHash = previousBlock.hashedString, let date = date.date else {
            return nil
        }
        self.date = date
        self.maker = maker
        self.signature = signature
        self.previousBlockNonce = previousBlock.nonce
        self.previousBlockHash = previousBlockHash
        self.previousBlockDifficulty = previousBlock.difficultyAsNonceLeadingZeroLength
        /*
         Update Next Difficulty
         */
        self.nextDifficulty = book.makeNextDifficulty(blockDate: date)
        self.publicKey = publicKey
        self.book = book
        if let id = id {
            self.id = id
        } else {
            self.id = ""
        }

        /*
         Book標準タイミング：
         Block生成が30分に３回以内に収まるように nonce padding difficulty難易度 を設定する
            
            BookしたBlockの履歴を取得する
            ↓
            過去30分以内に3block以上生成されていたら
            ↓
            paddingZeroLength を１増やす
         */
        self.difficultyAsNonceLeadingZeroLength = paddingZeroLengthForNonce
        if let nonceAsData = nonceAsData {
            self.nonce = Nonce(paddingZeroLength: paddingZeroLengthForNonce, preBlockNonce: previousBlockNonce, nonceAsData: nonceAsData)
        } else {
            /*
             Switchable Which Use CPU Power or GPU Power.
             */
            self.nonce = Nonce(paddingZeroLength: paddingZeroLengthForNonce, preBlockNonce: previousBlockNonce)
        }
        self.id = setupId()
    }

    static let genesisBlockId = "000010000100001000011"
    static let nullBlockId = "000000000000000000000"

    init(genesis maker: String = String(repeating: "0", count: 64)) {
        Log()
        self.maker = String(repeating: "0", count: 64)
        self.signature = Data(repeating: UInt8.zero, count: 64)
        self.previousBlockNonce = Nonce.genesisBlockNonce
        self.previousBlockDifficulty = Nonce.genesisBlockDifficulty
        self.nonce = Nonce.genesisBlockNonce
        self.difficultyAsNonceLeadingZeroLength = Nonce.defaultZeroLength
        self.nextDifficulty = Nonce.defaultZeroLength
        self.previousBlockHash = ""
        self.publicKey = Data.DataNull
        self.date = Date.null
        self.book = Book(signature: Data.DataNull, currentDifficultyAsNonceLeadingZeroLength: 0)
        self.id = Block.genesisBlockId
    }

    init(Null maker: String = String(repeating: "0", count: 64)) {
        Log()
        self.maker = String(repeating: "0", count: 64)
        self.signature = Data(repeating: UInt8.zero, count: 64)
        self.previousBlockNonce = Nonce.genesisBlockNonce
        self.previousBlockDifficulty = Nonce.genesisBlockDifficulty
        self.nonce = Nonce.genesisBlockNonce
        self.difficultyAsNonceLeadingZeroLength = Nonce.defaultZeroLength
        self.nextDifficulty = Nonce.defaultZeroLength
        self.previousBlockHash = ""
        self.publicKey = Data.DataNull
        self.date = Date.null
        self.book = Book(signature: Data.DataNull, currentDifficultyAsNonceLeadingZeroLength: 0)
        self.id = Block.nullBlockId
    }

    public static func block(from dictionary: [String: Any], book: Book, node: Node) -> Block? {
        Log()
        if let date = dictionary["date"] as? String,
            let maker = dictionary["maker"] as? String,
            let signatureAsString = dictionary["signature"] as? String,
            let signature = signatureAsString.base64DecodedData,
            let previousBlockHash = dictionary["previousBlockHash"] as? String,
            let previousBlockNonce = dictionary["previousBlockNonce"] as? String,
            let previousBlockDifficulty = dictionary["previousBlockDifficulty"] as? String, let previousBlockDifficultyAsInt = Int(previousBlockDifficulty),
            let nonceAsHex = dictionary["nonce"] as? String,
            let difficultyAsNonceLeadingZeroLength = dictionary["difficultyAsNonceLeadingZeroLength"] as? String, let difficultyAsNonceLeadingZeroLengthAsInt = Int(difficultyAsNonceLeadingZeroLength),
            let publicKeyString = dictionary["publicKey"] as? String,
            let publicKey = publicKeyString.base64DecodedData,
            let transactions = dictionary["transactions"] as? String {
            if var block = Block(date: date, maker: maker, signature: signature, previousBlockHash: previousBlockHash, previousBlockNonce: previousBlockNonce, previousBlockDifficulty: previousBlockDifficultyAsInt, nonceAsHex: nonceAsHex, publicKey: publicKey, paddingZeroLength: difficultyAsNonceLeadingZeroLengthAsInt, book: book) {
                if block.add(transactions: transactions, makerDhtAddressAsHexString: maker, publicKeyAsData: publicKey, node: node) {
                    return block
                }
            }
        }
        return nil
    }

    /*
     Paper:
     consensus mechanism

     proof of works
     無効なブロックはその作業を拒否することで拒否します。
     
     electronic payment system
        Trust →cryptographic proof
        信頼(信頼できる第三者  trusted third party)　→暗号による証明
        ↓
        当事者が直接取引できる

     peer-to-peer distributed timestamp server
     We define an electronic coin as a chain of digital signatures.

     */
    private func rejectBlock() {
        
        //#now
    }

    /*
     Genesis     最初のブロック
     */
    public static var genesis: Block = Block(genesis: String(repeating: "0", count: 64))

    /*
     Add         Transactionを追加する
         署名確認、残高確認を行う
     */
    public mutating func add(transactions transactionAsJsonArrayString: String, makerDhtAddressAsHexString: OverlayNetworkAddressAsHexString, publicKeyAsData: PublicKey, node: Node) -> Bool {
        Log()
        var addedAll = true
        let signer = Signer(publicKeyAsData: publicKeyAsData, makerDhtAddressAsHexString: makerDhtAddressAsHexString)
        let transactions = Transactions.Maker(book: self.book, string: transactionAsJsonArrayString, signer: signer).stringToTransactions
        Log(transactions?.count)
        transactions?.forEach {
            Log()
            if let transactionSignature = $0.signature, let transactionId = $0.transactionId, let date = $0.date, let publicKey = $0.publicKey {
                Log()
                let validTransactionCauseAdded = addTransaction(claim: $0.claim, claimObject: $0.claimObject, type: $0.type.rawValue, makerDhtAddressAsHexString: $0.makerDhtAddressAsHexString, signature: transactionSignature, publicKeyAsData: publicKey, transactionId: transactionId, date: date)
                if addedAll && validTransactionCauseAdded {
                    addedAll = true
                } else {
                    addedAll = false
                }
            }
        }
        /*
         transaction配列の最後にBooker手数料と
         定期実施 transaction（BasicIncome など）をblockの最後に追加する
         
         #pending
         */
        //        Log(self.transactions.count)
        //#test 一時的にコメントアウトした #あと　booker手数料
        //        if self.transactions.count <= Block.maxTransactionsInABlock {
        //            if let signer = node.signer(), let publicKeyAsBase64String = signer.publicKeyForSignature?.rawRepresentation.base64String {
        //                let claimObject = ClaimOnPay.Object(destination: "")
        //                if let bookerFeeTransaction = TransactionType.pay.construct(claim: ClaimOnPay.bookerFee, claimObject: claimObject, makerDhtAddressAsHexString: self.maker, publicKey: publicKeyAsBase64String, book: node.book, signer: signer, peerSigner: signer, creditOnRight: ClaimOnPay.bookerFee.fee),
        //                    let signatureString = bookerFeeTransaction.signature?.base64String,
        //                    let transactionId = bookerFeeTransaction.transactionId,
        //                    let date = bookerFeeTransaction.date {
        //                    addTransaction(claim: bookerFeeTransaction.claim, claimObject: bookerFeeTransaction.claimObject, type: bookerFeeTransaction.type.rawValue, makerDhtAddressAsHexString: bookerFeeTransaction.makerDhtAddressAsHexString, signature: signatureString, base64EncodedPublicKeyString: bookerFeeTransaction.publicKey, transactionId: transactionId, date: date)
        //                }
        //            }
        //        }
        Log(self.transactions.count)
        return addedAll
    }

    /*
     Validate A Transaction
     &
     Add A Transaction to Block
     */
    public mutating func addTransaction(claim: any Claim, claimObject: any ClaimObject, type: String, makerDhtAddressAsHexString: OverlayNetworkAddressAsHexString, signature: Signature, publicKeyAsData: PublicKey, transactionId: TransactionIdentification, date: Date) -> Bool {
        Log()
        if isThereSameTransaction(signature: signature) {
            Log("Duplicate Transaction in Block.")
        } else {
            Log()
            /*
             Validate Transaction, Then Add to Block.
             */
            let signer = Signer(publicKeyAsData: publicKeyAsData, makerDhtAddressAsHexString: makerDhtAddressAsHexString)
            let signatureData = signature.signatureToData
            Log("++Validation")
            Log("claimObject: \(claimObject)")
            Log("publickey: \(publicKeyAsData.publicKeyToString)")
            Log("signature: \(signature)")
            Log("signatureData: \(signatureData.base64String)")
            Log("makerDhtAddressAsHexString: \(makerDhtAddressAsHexString)")
            Log("transactionId: \(transactionId)")
            Log("date: \(date)")
            
            if let type = TransactionType(rawValue: type) {
                Log()
                if let transaction = type.construct(claim: claim, claimObject: claimObject, makerDhtAddressAsHexString: makerDhtAddressAsHexString, publicKey: publicKeyAsData, signature: signatureData, book: self.book, signer: signer, transactionId: transactionId, date: date) {
                    Log(transaction.jsonString)
                    if transaction.validate() {
                        Log("Valid Transaction Cause Add to Block. \(transaction.transactionId)")
                        self.transactions += [transaction]
                        return true
                    }
                    Log("Invalidate Transaction.")
                }
            }
            Log("Can NOT Build Transaction Data.")
            Log()
        }
        return false
    }
    
    /*
     In Block, Detect There Find Same Transaction.
     */
    private func isThereSameTransaction(signature: Signature) -> Bool {
        Log()
        //Have Same Transaction.
        for transaction in transactions {
            if let havingSignature = transaction.signature, havingSignature.equal(signature) {
                return true
            }
        }
        return false
    }
    
    /*
     "[
         {"Destination": "BroadCastMail",
             "Claim": "FT",
             "Fee": "1"},
         {"abc": "A Transaction Content"},
         {"abc": "A Transaction Content"}
     ]"
     */
    var reducedTransactionsInBlock: String {
        let transactionsInBlockAsJson = transactions.reduce("[") {
            $0 + $1.jsonString + ","
        }
        let trimLastSemicolonIndex = transactionsInBlockAsJson.index(transactionsInBlockAsJson.endIndex, offsetBy: -1)
        return transactionsInBlockAsJson[transactionsInBlockAsJson.startIndex..<trimLastSemicolonIndex] + "]"
    }
    
    /*
     署名を追加してから、Publishする
     */
    mutating func send(node: any NodeProtocol, signer: Signer) {
        Log()
        /*
         As Block Have Not Signature yet (Unsigned), Sign it.
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
    
    let serialQueue = DispatchQueue(label: "org.webbanana.org.overlayNetwork", target: DispatchQueue.global())

    /*
     Publish     Transactionを発行する
     */
    public func publish(on node: any NodeProtocol, with signer: Signer) {
        Log()
        /*
         Transactionを known node にブロードキャストする（Mail）
         自分が知っているnodeに対して block を送信する
         known node:
         predecessor, successor, babysitter(arbitrary node)
         */
        guard let signatureString = self.signature?.toString else {
            Log("Void Signature cause Can NOT Publish Block.")
            return
        }
        Log(signer.privateKeyForSignature?.rawRepresentation.base64String)
        
        do {
            let contentAsData = self.content
            Log("contents: \(contentAsData.utf8String)")    //平文
            Log(contentAsData.utf8String)
            let operands = [self.type.rawValue, self.date.toUTCString, contentAsData.utf8String, signer.base64EncodedPublicKeyForSignatureString, self.maker.toString, self.nonce.asHex]
            
            //↓ オペランドを圧縮する場合
            //                Log(self.content.count)
            //                let nsData: NSData = NSData(data: self.content)
            //                guard let compressedData: Data = try? nsData.compressed(using: .zlib) as Data else {
            //                    fatalError("Fail to Compress Data")
            //                }
            //                Log(compressedData.count)
            //                let operands = [self.type.rawValue, compressedData.base64String, signatureString, signer.base64EncodedPublicKeyForSignatureString, self.maker]
            Log(operands)
            Log(node.predecessor?.getIp)
            if let predecessorIp = node.predecessor?.getIp {
                serialQueue.async {
                    Command.publishBlock.send(node: node, to: predecessorIp, operands: operands) { string in
                        Log(string)
                    }
                }
            }
            Log(node.successor?.getIp)
            if let successorIp = node.successor?.getIp {
                serialQueue.async {
                    Command.publishBlock.send(node: node, to: successorIp, operands: operands) { string in
                        Log(string)
                    }
                }
            }
            Log(node.babysitterNode?.getIp)
            if let babysitterIp = node.babysitterNode?.getIp {
                serialQueue.async {
                    Command.publishBlock.send(node: node, to: babysitterIp, operands: operands) { string in
                        Log(string)
                    }
                }
            }
        } catch {
            Log(error)
        }
    }
    
    /*
     FetchTime(UTC)  ブロック生成時間
     */
    public func fetchTime() {
        
    }

    /*
     Sign        署名する
         Hash
         Base64
         Encrypt(ECDSA 256)

     */
    public mutating func sign(with signer: Signer) throws {
        Log()
        if let contentHashedData = self.contentForSignAndValidate.hashedData?.toData, let signature = try signer.sign(contentAsData: contentHashedData) {
            Log("SIGN#-- Block")
            Log("raw data: \(self.contentForSignAndValidate.utf8String)")
            Log("data: \(self.contentForSignAndValidate.base64String)")
            Log("hash: \(contentHashedData.base64String)")
            Log("signature: \(signature.toString)")
            Log("publicKey: \(signer.publicKeyForSignature?.rawRepresentation.base64String)")
            self.signature = signature
        }
    }

    /*
     utf8 →Data
     */
    var content: Data {
        var jsonString = """
{"id":"\(self.id)",
"date":"\(self.date.utcTimeString)",
"maker":"\(self.maker)",
"type":"\(self.type.rawValue)",
"signature":"\(self.signature?.toString ?? "")",
"previousBlockHash":"\(self.previousBlockHash)",
"previousBlockNonce":"\(self.previousBlockNonce.asHex)",
"previousBlockDifficulty":"\(self.previousBlockDifficulty)",
"nextDifficulty":"\(self.nextDifficulty)",
"nonce":"\(self.nonce.asHex)",
"difficultyAsNonceLeadingZeroLength":"\(self.difficultyAsNonceLeadingZeroLength)",
"publicKey":"\(self.publicKey.publicKeyToString)"
"""
        
        jsonString += transactions.enumerated().reduce("") {
//            Log($1.offset)
            var leadPadding = ""
            var trailPadding = ","
            if $1.offset == 0 {
                leadPadding = ",\"transactions\":["
            }
            if $1.offset == transactions.count - 1 {
                trailPadding = "]"
            }
            return $0 + leadPadding + $1.element.jsonString + trailPadding
        }
        jsonString += "}"
        //remove \n
        jsonString = jsonString.removeNewLineChars
        let data = jsonString.utf8DecodedData
        if let data = data {
            return data
        }
        return Data.DataNull
    }

    var contentForSignAndValidate: Data {
        var jsonString = """
{"id":"\(self.id)",
"date":"\(self.date.utcTimeString)",
"maker":"\(self.maker)",
"type":"\(self.type.rawValue)",
"signature":"",
"previousBlockHash":"\(self.previousBlockHash)",
"previousBlockNonce":"\(self.previousBlockNonce.asHex)",
"nonce":"\(self.nonce.asHex)",
"difficultyAsNonceLeadingZeroLength":"\(self.difficultyAsNonceLeadingZeroLength)",
"publicKey":"\(self.publicKey.publicKeyToString)"
"""

        jsonString += transactions.enumerated().reduce("") {
//            Log($1.offset)
            var leadPadding = ""
            var trailPadding = ","
            if $1.offset == 0 {
                leadPadding = ",\"transactions\":["
            }
            if $1.offset == transactions.count - 1 {
                trailPadding = "]"
            }
            return $0 + leadPadding + $1.element.jsonString + trailPadding
        }
        jsonString += "}"
        //remove \n
        jsonString = jsonString.removeNewLineChars
        let data = jsonString.utf8DecodedData
        if let data = data {
            return data
        }
        return Data.DataNull
    }
    
    /*
        Validate Block
        有効性チェックする
     */
    public func validate(signature: Signature, signer: Signer) -> Bool {
        Log()
        var validated = true
        transactions.forEach {
            Log()
            if $0.validate() {
                Log()
            } else {
                Log()
                validated = false
            }
        }
        Log()

        if validated {
            if let contentHashedData = self.contentForSignAndValidate.hashedData?.toData {
                Log("SIGN#++ Block")
                Log("raw data: \(self.contentForSignAndValidate.utf8String)")
                Log("data: \(self.contentForSignAndValidate.base64String)")
                Log("hash: \(contentHashedData.base64String)")
                Log("signature: \(signature.toString)")
                Log("publicKey: \(signer.publicKeyForSignature?.rawRepresentation.base64String)")
                do {
                    return try self.verify(data: contentHashedData, signature: signature, signer: signer)
                } catch {
                    Log(error)
                }
            }
        }
        Log()
        return false
    }

    public func verify(data: Data, signature: Signature, signer: Signer) throws -> Bool {
        Log("Verify Block.")
        Log(data.utf8String)
        Log(signature.toString)
        Log(signer.publicKeyForSignature?.rawRepresentation.base64String)
        
        let verifySucceeded = try signer.verify(data: data, signature: signature)
        Log("Verify Block? \(verifySucceeded)")
        return verifySucceeded
    }

    /*
     Store Block to Device's Storage As Secondary Candidate.
     
     Format: Json
     */
    private let archivedDirectory = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first! + "/block/"
    private let archiveFile = "secondaryCandidateBlock.json"
    private var archiveFilePath: String {
        self.archivedDirectory + self.archiveFile
    }
    public func storeAsSecondaryCandidate() {
        Log()
        do {
            let storeUrl = URL(fileURLWithPath: self.archiveFilePath)

            /*
             [
                {
                 "transactionId":"\(transactionId)",
                 "date":"\(dateString)",
                 "type":"\(self.type.rawValue)",
                 "makerDhtAddressAsHexString":"\(self.makerDhtAddressAsHexString)",
                 "contents":"\(self.content)",
                 "signature":"\(signature)",
                 "publicKey":"\(self.publicKey)"
                },
                ...
             ]
             */
            let jsonAsData = self.content
            Log("\(jsonAsData.utf8String ?? "")")
            try jsonAsData.append(to: storeUrl, truncate: true)
        } catch {
            Log("Save Json Error \(error)")
        }
    }

    public func isCachedForSecondaryCandidate() -> Bool {
        Log()
        if !FileManager.default.fileExists(atPath: self.archiveFilePath) {
            Log("No Cached")
            return false
        }
        Log("Cached")
        return true
    }

    public func fetchSecondaryCandidate() -> [String: String]? {
        Log()
        if self.isCachedForSecondaryCandidate() {
            Log()
            do {
                let url = URL(fileURLWithPath: self.archiveFilePath)
                let data = try Data(contentsOf: url)
                Log("\(data.utf8String ?? "")")
                if let jsonAsString = data.utf8String {
                    return jsonAsString.jsonToDictionary
                }
            } catch {
                Log("Error Fetching Json Data: \(error)")
            }
        }
        return nil
    }
}
