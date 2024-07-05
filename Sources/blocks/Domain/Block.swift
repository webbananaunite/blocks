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
    private func setupId() -> BlockIdentification? {
        /*
         block内Transactionすべての内容と現在時間をハッシュしてUniqueな文字列を生成する
         */
        var blockContentString = """
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
        //remove \n
        blockContentString = blockContentString.removeNewLineChars
        let reducedTransactions = transactions.reduce("") {
            $1.useAsHash
        }
        Log(blockContentString + reducedTransactions)
        let hashedString = (blockContentString + reducedTransactions).hashedStringAsHex?.toString ?? nil
        Log(hashedString)
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
    var previousBlockNonceAsCompressedString: String?
    
    let previousBlockDifficulty: Difficulty
    let nextDifficulty: Difficulty
    
    public var nonce: Nonce
    var nonceAsCompressedString: String?
    /*
     Value Range is 0 - 512 (Nonce.hashedBits)
     
     Default value is 16
     */
    public var difficultyAsNonceLeadingZeroLength: Difficulty

    private mutating func makeNonce() {
        Log()
        self.nonce = Nonce(preBlockNonce: self.previousBlockNonce)
    }
    
    /*
     Caution:
     Make Compressed HexaDecimal String cause This Function Comsume very large Time.
     */
    var hashedString: HashedString? {
        if let contentAsUtf8String = self.contentAsNoCompressed.utf8String {
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
    init?(date: String, maker: OverlayNetworkAddressAsHexString, signature: Signature, previousBlockHash: HashedString, previousBlockNonce: String, previousBlockDifficulty: Difficulty, nextDifficulty: Difficulty, nonceAsHex: String, publicKey: PublicKey, paddingZeroLength: Difficulty, book: Book, id: BlockIdentification? = nil) {
        Log()
        guard let previousNonceAsData = previousBlockNonce.hexadecimalDecodedData, let nonceAsData = nonceAsHex.hexadecimalDecodedData, let date = date.date else {
            return nil
        }
        let signatureAsData = signature.signatureToData
        self.date = date
        self.maker = maker
        self.signature = signatureAsData
        self.previousBlockHash = previousBlockHash
        self.previousBlockNonce = Nonce(paddingZeroLength: previousBlockDifficulty, nonceAsData: previousNonceAsData)
        self.previousBlockNonceAsCompressedString = self.previousBlockNonce.compressedHexaDecimalString
        self.previousBlockDifficulty = previousBlockDifficulty
        self.nextDifficulty = nextDifficulty

        self.nonce = Nonce(paddingZeroLength: paddingZeroLength, nonceAsData: nonceAsData)
        self.nonceAsCompressedString = self.nonce.compressedHexaDecimalString
        self.difficultyAsNonceLeadingZeroLength = paddingZeroLength
        self.publicKey = publicKey
        self.book = book
        if let id = id {
            self.id = id
        } else {
            self.id = ""
            guard let id = setupId() else {
                return nil
            }
            self.id = id
        }
    }

    init?(maker: OverlayNetworkAddressAsHexString, signature: Signature? = nil, previousBlock: Block, nonceAsData: Data? = nil, publicKey: PublicKey, date: String, paddingZeroLengthForNonce: Difficulty? = nil, book: Book, id: BlockIdentification? = nil, chainable: Book.ChainableResult, previousBlockHash: HashedString?, indexInBranchPoint: Int?, branchHash: HashedString?, indexInBranchChain: Int?) {
        Log(chainable)
        Log(previousBlockHash)
        Log(previousBlock.hashedString)
        guard let previousBlockHashedString = previousBlock.hashedString, let date = date.date, let nextDifficulty = book.makeNextDifficulty(blockDate: date, chainable: chainable, previousBlockHash: previousBlockHash, indexInBranchPoint: indexInBranchPoint, branchPoint: branchHash, indexInBranchChain: indexInBranchChain) else {
            return nil
        }
        self.date = date
        self.maker = maker
        self.signature = signature
        self.previousBlockNonce = previousBlock.nonce
        self.previousBlockNonceAsCompressedString = self.previousBlockNonce.compressedHexaDecimalString
        self.previousBlockHash = previousBlockHashedString
        
        self.previousBlockDifficulty = previousBlock.difficultyAsNonceLeadingZeroLength
        self.nextDifficulty = nextDifficulty
        self.publicKey = publicKey
        self.book = book

        /*
         Book標準タイミング：
         Block生成が30分に３回以内に収まるように nonce padding difficulty難易度 を設定する
            
            BookしたBlockの履歴を取得する
            ↓
            過去30分以内に3block以上生成されていたら
            ↓
            paddingZeroLength を１増やす
         */
        if let paddingZeroLengthForNonce = paddingZeroLengthForNonce, let nonceAsData = nonceAsData {
            self.difficultyAsNonceLeadingZeroLength = paddingZeroLengthForNonce
            self.nonce = Nonce(paddingZeroLength: paddingZeroLengthForNonce, preBlockNonce: previousBlockNonce, nonceAsData: nonceAsData)
        } else {
            /*
             Switchable Which Use CPU Power or GPU Power.
             */
            Log(previousBlock.nextDifficulty)
            self.difficultyAsNonceLeadingZeroLength = previousBlock.nextDifficulty
            self.nonce = Nonce(paddingZeroLength: previousBlock.nextDifficulty, preBlockNonce: previousBlockNonce)
        }
        self.nonceAsCompressedString = self.nonce.compressedHexaDecimalString
        if let id = id {
            self.id = id
        } else {
            self.id = ""
            guard let id = setupId() else {
                return nil
            }
            self.id = id
        }
    }

    static let genesisBlockId = "000010000100001000011"
    static let nullBlockId = "000000000000000000000"

    init(genesis maker: String = String(repeating: "0", count: 64)) {
        Log()
        self.maker = String(repeating: "0", count: 64)
        self.signature = Data(repeating: UInt8.zero, count: 64)
        self.previousBlockNonce = Nonce.genesisBlockNonce
        self.previousBlockNonceAsCompressedString = self.previousBlockNonce.compressedHexaDecimalString
        self.previousBlockDifficulty = Nonce.genesisBlockDifficulty
        self.nonce = Nonce.genesisBlockNonce
        self.nonceAsCompressedString = self.nonce.compressedHexaDecimalString
        self.difficultyAsNonceLeadingZeroLength = Nonce.defaultZeroLength
        self.nextDifficulty = Nonce.defaultZeroLength
        self.previousBlockHash = ""
        self.publicKey = Data.DataNull
        self.date = Date.null
        self.book = Book(signature: Data.DataNull)
        self.id = Block.genesisBlockId
    }

    init(Null maker: String = String(repeating: "0", count: 64)) {
        Log()
        self.maker = String(repeating: "0", count: 64)
        self.signature = Data(repeating: UInt8.zero, count: 64)
        self.previousBlockNonce = Nonce.genesisBlockNonce
        self.previousBlockNonceAsCompressedString = self.previousBlockNonce.compressedHexaDecimalString
        self.previousBlockDifficulty = Nonce.genesisBlockDifficulty
        self.nonce = Nonce.genesisBlockNonce
        self.nonceAsCompressedString = self.nonce.compressedHexaDecimalString
        self.difficultyAsNonceLeadingZeroLength = Nonce.defaultZeroLength
        self.nextDifficulty = Nonce.defaultZeroLength
        self.previousBlockHash = ""
        self.publicKey = Data.DataNull
        self.date = Date.null
        self.book = Book(signature: Data.DataNull)
        self.id = Block.nullBlockId
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
    /*
     Add Multi Owner's Transactions to Block.
     Use At Received PB (Publish Block) Command, and storeAsSecondaryCandidate()
     
     Block#storeAsSecondaryCandidate() →Block#block(from:)から使う関数
     
     18:19:15 Block.swift storeAsSecondaryCandidate() l.731 
     {
     "id":"cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e","date":"2024-01-16T09:19:11.860Z","maker":"f87f3ce797b4fcdd28b33987751f821f251b61b7f16b31dbf38888e560a2ec0c1492fc41332ce86b330cc98cb2ac8bdcf482c61703ecfdcd58d7b94f2ae29876","type":"Block","signature":"CZvtLX/FDFQDrwPrOs1HVBaaCHHjC5jpA/69KA7yLkvM2Kb+3vnhbCx9K+XWU7WB5Z7ZPEXvGt1oo2aMs9QiCA==","previousBlockHash":"ee1466ebd3df312057444a9054b1a7cd63aaf21d80ffdb1090586a211b9e9d12293b04d56438d00992b9817a37ff1c2a96cfa84d4600b767dd6b0a57f59adf3e","previousBlockNonce":"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000","previousBlockDifficulty":"16","nextDifficulty":"18","nonce":"ffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010","difficultyAsNonceLeadingZeroLength":"16","publicKey":"s6TJx6hRdW2rp4RVOYOuYNDtckleOQuHngKyU5svzag=",
     
     "transactions":[
            {
            "transactionId":"PScf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e","date":"2024-01-16T09:19:11.339Z","type":"person","makerDhtAddressAsHexString":"d07a803fe6eff5c730357455dbf19d729894e591b7f99f0cd1c7cc49dca0d7a69cc57f77c6afa42436db113ddcb5a1544ffbc21b0f10a552901ad8501e753675","publicKey":"fybBwm9cGa4ul0H0T+0+1hq6vm2DAYT4B9Mb0NSDwS8=","claim":"FT",
            "claimObject":{"CombinedSealedBox":"","Description":"","Destination":"BroadCast","PersonalData":"","PublicKeyForEncryption":"LIzsJsVk7JLzjml50yP9jGQN6YOwe1T1kZi1nE2oJlk="},"signature":"UiuWPw70h3/TwEwxwX9ixgAbshqpxXlHwlnnxuX+mMzaO1I+p4QdP7w3SnpYKZyMaTBcA9l4L6gGnN7dydxFBg=="
            }
        ]
     }
     */
//    public mutating func add(multipleMakerTransactions transactionsAsDictionary: [[String : Any]]?, chainable: Book.ChainableResult = .chainableBlock, branchChainHash: HashedString?, indexInBranchChain: Int?) -> Bool {
    public mutating func add(multipleMakerTransactions transactionsAsDictionary: [[String : Any]]?, chainable: Book.ChainableResult = .chainableBlock, branchChainHash: HashedString?, indexInBranchChain: Int?, node: Node) -> Bool {
        Log(transactionsAsDictionary)
        var addedAll = true
        transactionsAsDictionary?.forEach {
            Log($0)
            if let makerDhtAddressAsHexString = $0["makerDhtAddressAsHexString"] as? String, let publicKeyAsBase64String = $0["publicKey"] as? String,
               let publicKeyAsData: PublicKey = publicKeyAsBase64String.base64DecodedData {
                Log()
                let result = self.add(singleMakerTransactions: [$0], makerDhtAddressAsHexString: makerDhtAddressAsHexString, publicKeyAsData: publicKeyAsData, chainable: chainable, branchChainHash: branchChainHash, indexInBranchChain: indexInBranchChain, node: node)
                if !result {
                    addedAll = false
                }
            }
        }
        Log(addedAll)
        return addedAll
    }
    
    /*
     Add Single Owner's Transactions to Block.
     Use At Received PT (Publish Transaction) Command.
     */
    public mutating func add(singleMakerTransactions transactionsAsDictionary: [[String : Any]]?, makerDhtAddressAsHexString: OverlayNetworkAddressAsHexString, publicKeyAsData: PublicKey, chainable: Book.ChainableResult = .chainableBlock, branchChainHash: HashedString?, indexInBranchChain: Int?, node: Node) -> Bool {
        Log()
        guard let transactionsAsDictionary = transactionsAsDictionary else {
            return false
        }
        var addedAll = true
        let signerOnTransactionMaker = Signer(publicKeyAsData: publicKeyAsData, makerDhtAddressAsHexString: makerDhtAddressAsHexString)
        let transactionAsJsonArrayString = transactionsAsDictionary.dictionarysToJsonString
        let transactions = Transactions.Maker(book: self.book, string: transactionAsJsonArrayString, signer: signerOnTransactionMaker).stringToTransactions
        Log(transactions?.count)
        transactions?.forEach {
            Log()
            if let transactionSignature = $0.signature, let transactionId = $0.transactionId, let date = $0.date, let publicKey = $0.publicKey {
                Log()
                let validTransactionCauseAdded = addTransaction(claim: $0.claim, claimObject: $0.claimObject, type: $0.type.rawValue, makerDhtAddressAsHexString: $0.makerDhtAddressAsHexString, signature: transactionSignature, publicKeyAsData: publicKey, transactionId: transactionId, date: date, chainable: chainable, branchChainHash: branchChainHash, indexInBranchChain: indexInBranchChain)
                if addedAll && validTransactionCauseAdded {
                    addedAll = true
                } else {
                    addedAll = false
                }
            }
        }
        Log("Transaction Counter in Block Added Single Maker Transactions: \(self.transactions.count)")
        /*
         transaction配列の最後にBooker手数料と
         定期実施 transaction（BasicIncome など）をblockの最後に追加する
         */
        if self.transactions.count <= Block.maxTransactionsInABlock {
            if let signer = node.signer(), let publicKeyAsBase64String = signer.publicKeyForSignature?.rawRepresentation.base64String, let publicKey = publicKeyAsBase64String as? PublicKey {
                let claimObject = ClaimOnPay.Object(destination: "")
                if let bookerFeeTransaction = TransactionType.pay.construct(claim: ClaimOnPay.bookerFee, claimObject: claimObject, makerDhtAddressAsHexString: self.maker, publicKey: publicKey, book: node.book, signer: signer, peerSigner: signer, creditOnRight: ClaimOnPay.bookerFee.fee),
                    let bookerFeeTransactionSignature = bookerFeeTransaction.signature,
                    let transactionId = bookerFeeTransaction.transactionId,
                    let bookerFeeTransactionPublicKey = bookerFeeTransaction.publicKey,
                    let date = bookerFeeTransaction.date {
                    let validTransactionCauseAdded = addTransaction(claim: bookerFeeTransaction.claim, claimObject: bookerFeeTransaction.claimObject, type: bookerFeeTransaction.type.rawValue, makerDhtAddressAsHexString: bookerFeeTransaction.makerDhtAddressAsHexString, signature: bookerFeeTransactionSignature,
                                   publicKeyAsData: bookerFeeTransactionPublicKey, transactionId: transactionId, date: date, chainable: chainable, branchChainHash: branchChainHash, indexInBranchChain: indexInBranchChain)
                    if addedAll && validTransactionCauseAdded {
                        addedAll = true
                    } else {
                        addedAll = false
                    }
                }
            }
        }
        Log("Transaction Counter in Block Added A Booker Fee Transaction: \(self.transactions.count)")
        return addedAll
    }

    /*
     Validate A Transaction
     &
     Add A Transaction to Block
     */
    public mutating func addTransaction(claim: any Claim, claimObject: any ClaimObject, type: String, makerDhtAddressAsHexString: OverlayNetworkAddressAsHexString, signature: Signature, publicKeyAsData: PublicKey, transactionId: TransactionIdentification, date: Date, chainable: Book.ChainableResult, branchChainHash: HashedString?, indexInBranchChain: Int?) -> Bool {
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
                    if transaction.validate(chainable: chainable, branchChainHash: branchChainHash, indexInBranchChain: indexInBranchChain) {
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
     Once Signed, Chain to Own Node's Book.
     */
    mutating func chain(previousBlock: Block, node: any NodeProtocol, signer: Signer) {
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
        (node as! Node).book.chain(block: self, chainable: .chainableBlock, previousBlock: previousBlock, node: node as! Node)
    }
    
    /*
     Once Signed, Publish Block to known Nodes.
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
            let operands = [self.type.rawValue, self.date.toUTCString, contentAsData.utf8String]

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
            Log(node.predecessor?.dhtAddressAsHexString)
            if let predecessorOverlayNetworkAddress = node.predecessor?.dhtAddressAsHexString {
                serialQueue.async {
                    Command.publishBlock.send(node: node, to: predecessorOverlayNetworkAddress, operands: operands) { string in
                        Log(string)
                    }
                }
            }
            Log(node.successor?.getIp)
            Log(node.successor?.dhtAddressAsHexString)
            if let successorOverlayNetworkAddress = node.successor?.dhtAddressAsHexString {
                serialQueue.async {
                    Command.publishBlock.send(node: node, to: successorOverlayNetworkAddress, operands: operands) { string in
                        Log(string)
                    }
                }
            }
            Log(node.babysitterNode?.getIp)
            Log(node.babysitterNode?.dhtAddressAsHexString)
            if let babysitterOverlayNetworkAddress = node.babysitterNode?.dhtAddressAsHexString {
                serialQueue.async {
                    Command.publishBlock.send(node: node, to: babysitterOverlayNetworkAddress, operands: operands) { string in
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
     Caution:
     Make Compressed HexaDecimal String cause This Function Comsume very large Time.

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
"previousBlockNonce":"\(self.previousBlockNonceAsCompressedString != nil ? self.previousBlockNonceAsCompressedString! : self.previousBlockNonce.compressedHexaDecimalString)",
"previousBlockDifficulty":"\(self.previousBlockDifficulty)",
"nextDifficulty":"\(self.nextDifficulty)",
"nonce":"\(self.nonceAsCompressedString != nil ? self.nonceAsCompressedString! : self.nonce.compressedHexaDecimalString)",
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
    
    var contentAsNoCompressed: Data {
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
    public func validate(signature: Signature, signer: Signer, chainable: Book.ChainableResult = .chainableBlock, branchChainHash: HashedString?, indexInBranchChain: Int?) -> Bool {
        Log()
        var validated = true
        transactions.forEach {
            Log()
            if $0.validate(chainable: chainable, branchChainHash: branchChainHash, indexInBranchChain: indexInBranchChain) {
                Log()
            } else {
                Log()
                validated = false
            }
        }
        Log()

        if validated {
            Log()
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
        Log(data.base64String)
        Log(signature.toString)
        Log(signer.publicKeyForSignature?.rawRepresentation.base64String)
        
        let verifySucceeded = try signer.verify(data: data, signature: signature)
        Log("Verify Block? \(verifySucceeded)")
        return verifySucceeded
    }
}
