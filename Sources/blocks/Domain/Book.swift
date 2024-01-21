//
//  Book.swift
//  blocks
//
//  Created by よういち on 2020/06/11.
//  Copyright © 2020 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation
import overlayNetwork

/*
 Book(Block配列)         ブロックの配列(一方向リスト構造)
    Proof of work
        問題から正解を得た最初の人だけがそのタイミングでBookできる
        Bookタイミング：５分ごと

 */
public struct Book {
    public var blocks = [Block]()
    public var signature: Signature
    public var lastBlock: Block? {
        blocks.last
    }
    /*
     Value Range is 0 - 512 (Nonce.bits)
     
     Default value is 16
     */
    public var currentDifficultyAsNonceLeadingZeroLength: Difficulty

    /*
     Extract（抽出）
         一連のBlockの中からあるアプリケーションのトランザクションを抽出する
     */
    public func extract(node: Node, transactionType: TransactionType, claim: (any Claim)? = nil, condition: String = "") -> [any Transaction] {
        Log()
        Log(transactionType)
        Log(claim)
        Log(node.dhtAddressAsHexString)
        var transactions = [any Transaction]()
        blocks.forEach {
            Log()
            $0.transactions.forEach {
                Log($0.jsonString)
                if $0.isMatch(type: transactionType, claim: claim, dhtAddressAsHexString: node.dhtAddressAsHexString) {
                    Log()
                    transactions += [$0]
                }
            }
        }
        Log(transactions.count)
        return transactions
    }

    /*
     #あと
     Behavior as Light Node,
        by milestone calculate amount of balance, and record it for each dht address.
     */
    public func balance(dhtAddressAsHexString: OverlayNetworkAddressAsHexString) -> BK {
        Log()
        //calculate balance on cached blocks.
        var transactions = [any Transaction]()
        var totalAmount: BK = Decimal.zero
        blocks.forEach {
            Log()
            $0.transactions.forEach {
                Log($0.jsonString)
                let (relatedTransaction, relatedType) = $0.filter(dhtAddressAsHexString: dhtAddressAsHexString)
                if relatedTransaction {
                    Log()
                    transactions += [$0]
                    if relatedType == .both {
                        //引き出し
                        totalAmount = totalAmount.asDecimal - $0.debitOnLeft.asDecimal
                        //預け入れ
                        totalAmount = totalAmount.asDecimal + $0.creditOnRight.asDecimal
                    } else if relatedType == .left {
                        //引き出し
                        totalAmount = totalAmount.asDecimal - $0.debitOnLeft.asDecimal
                    } else if relatedType == .right {
                        //預け入れ
                        totalAmount = totalAmount.asDecimal + $0.creditOnRight.asDecimal
                    }
                }
            }
        }
        Log(transactions.count)
        return totalAmount
    }

    /*
     Chain       ブロックをつなげる

     Validate Block, Then Chain the Block.

     
     [Proof of Works]
     Update Difficulty.

     
     [Long Branch]
     As Have the Block already, then Save Secondary Option Until next Proof of Work.
     
     Branch is Decided whether Received Block have as previousHash Chained last Block's hash
     or Secondary Option Block's hash.
     
     ＜Block（同じ先行Blockの２回目以降）＞ #あと
     次のBlockを受信して、長いブランチが確定するまでの間、
        長くなる場合に備えてBlockを第二候補として保存しておく
     
     Paper:
     最初に受け取ったブランチで作業しますが、長くなる場合に備えてもう一方のブランチを保存します。 次のproof-of-workが見つかり、1つのブランチが長くなると、この関係は解消されます。 他のブランチで動作していたノードは、長い方のブランチに切り替わります。
     */
    public mutating func chain(block: Block, chainable: ChainableResult, previousBlock: Block, node: Node) {
        Log()
        /*
         すでに登録されているか確認
         ↓
         公開鍵と作成者が同じかチェック validate block
         ↓
         Bookに追加する
         */
        let lastBlock = self.lastBlock ?? Block.genesis
        guard let signature = block.signature, let lastBlockSignature = lastBlock.signature else {
            /*
             Omit Block
             */
            Log("Detected Invalid Signature Cause Can NOT Chain!!")
            return
        }
        if lastBlockSignature.equal(signature) {
            /*
             Omit Block
             */
            Log("Detected Same Signature Block Cause Can NOT Chain!!")
            return
        }
        /*
         Validate Block, Then Chain the Block
         */
        let publicKeyAsData = block.publicKey
        let signer = Signer(publicKeyAsData: publicKeyAsData, makerDhtAddressAsHexString: block.maker)
        if let signatureData = block.signature {
            if block.validate(signature: signatureData, signer: signer, chainable: chainable) {
                Log("Validated A Block. id: \(block.id) hashedString: \(block.hashedString)")
                /*
                 difficulty
                 
                 前回のproof of workから今回のproof of workまでに{20分}より短い場合には
                 difficulty（先頭0数）をインクリメントする
                 
                 ok 2つ目のblockを受信した場合を考慮して変更する
                 ↑
                 difficultyを更新しない or 更新する前のdifficultyを使って検証する
                 ↑
                 ok 次のchain時のdifficultyをbookに記述する
                 */
                /*
                 Have Received a Block as Prime already, The Block Save as Secondary Candidate
                 until Next Proof of work.
                 */
                if self.lastBlock == nil {
                    Log()
                    //add genesis block
                    self.blocks += [Block.genesis]
                }
                LogEssential(chainable)
                switch chainable {
                case .secondaryCandidateBlocksNext:
                    /*
                     Lay Secondary Candidate Block First As The Block is Secondary Candidate Block's Next
                     
                     If Chain New Block to Secondary Candidate Block, and Remove Last Block.
                     */
                    LogEssential("The Block Chained in Legitimate Chain as Secondary Candidate Block's Next. popLast + [secondaryCandidateBlock, the block]")
                    let secondaryCandidateBlock = previousBlock
                    let _ = self.blocks.popLast()
                    self.blocks += [secondaryCandidateBlock, block]
                case .storeAsSecondaryCandidateBlock:
                    /*
                     Chain to Second Last Block As The Block's Previous Block Hash.
                     
                     Function detect whether same previous block to chain the block.
                     */
                    LogEssential("The Block Store As Secondary Candidate Block in Candidate Chain.")
                    LogEssential(block.hashedString)
                    LogEssential(block.content.utf8String)
                    block.storeAsSecondaryCandidate()
//                    #if DEBUG
//                    /*
//                     Reveal Secondary Candidate Block's Hash
//                     */
//                    if let secondaryCandidateAsDictionary = block.fetchSecondaryCandidate(),
//                       let secondaryCandidateBlock = Block.block(from: secondaryCandidateAsDictionary, book: self, node: node, chainable: .storeAsSecondaryCandidateBlock) {
//                        LogEssential("Just Stored secondaryCandidateBlockHash: \(secondaryCandidateBlock.hashedString)")
//                        LogEssential(secondaryCandidateBlock.content.utf8String)
//                    }
//                    #endif
                case .chainableBlock:
                    /*
                     Block is To Chain Next.
                     New Block As Cached Last Block's Next.
                     */
                    LogEssential("The Block Chained in Legitimate Chain.")
                    LogEssential("\(block.hashedString)")
                    LogEssential(block.content.utf8String)
                    //Append A Block
                    self.blocks += [block]
                    self.currentDifficultyAsNonceLeadingZeroLength = makeNextDifficulty(blockDate: block.date)
                    Log("currentDifficultyAsNonceLeadingZeroLength: \(self.currentDifficultyAsNonceLeadingZeroLength)")
                    Log(self.lastBlock)
                case .omitBlock:
                    break
                }
                #if DEBUG
                print("After Block Chained")
                if self.blocks.count == 0 {print("legitimate chain none")}
                for block in self.blocks.enumerated() {
                    print("legitimate chain \(block.offset): \(block.element.hashedString)", terminator: "\n")
                }
                if self.blocks.count > 0 {self.lastBlock?.isCachedForSecondaryCandidate()}
                /*
                 Reveal Secondary Candidate Block's Hash
                 */
                LogEssential("--Reveal Secondary Candidate Block's Hash")
                if let secondaryCandidateAsDictionary = block.fetchSecondaryCandidate(),
                   let secondaryCandidateBlock = Block.block(from: secondaryCandidateAsDictionary, book: self, node: node, chainable: .storeAsSecondaryCandidateBlock) {
                    LogEssential("Have Stored secondaryCandidateBlockHash: \(secondaryCandidateBlock.hashedString)")
                    LogEssential(secondaryCandidateBlock.content.utf8String)
                }
                LogEssential("++Reveal Secondary Candidate Block's Hash")
                #endif
                Log()
                //Store to Json File.
                if chainable == .secondaryCandidateBlocksNext || chainable == .chainableBlock {
                    self.recordLibrary()
                }
            }
        }
    }
    
    public enum ChainableResult {
        case secondaryCandidateBlocksNext       //Block is Secondary Candidate Block's Next.
        case storeAsSecondaryCandidateBlock     //Store As Secondary Candidate Block.
        case omitBlock          //The Block to Trash.(Omit the Block.
        case chainableBlock     //Block is To Chain Next.
    }
    public func chainable(previousBlockHash: HashedString, signatureForBlock: Signature, node: Node) -> (ChainableResult, Block, Difficulty) {
        Log("previousBlockHash: \(previousBlockHash)")
        #if DEBUG
        print("Pre Block Chained")
        if self.blocks.count == 0 {print("legitimate chain none")}
        for block in self.blocks.enumerated() {
            print("legitimate chain \(block.offset): \(block.element.hashedString)", terminator: "\n")
        }
        #endif
        let lastBlock = self.lastBlock ?? Block.genesis
        Log(self.blocks.count)
        guard let lastBlockSignature = lastBlock.signature else {
            LogEssential("The Block to Trash as Signature Invalid.")
            return (.omitBlock, Block(Null: ""), Int.max)
        }
        if lastBlockSignature.equal(signatureForBlock) {
            /*
             Duplicate Block
             */
            LogEssential("The Block to Trash as Signature Duplicate.")
            return (.omitBlock, Block(Null: ""), Int.max)
        }
        
        LogEssential("Legitimate Chain Chainable? \(previousBlockHash) != \(lastBlock.hashedString)")
        if let lastBlockHashedString = lastBlock.hashedString {
            if previousBlockHash.equal(lastBlockHashedString) {
                /*
                 Block is To Chain Next.
                 
                 New Block As Cached Last Block's Next.
                 */
                LogEssential("Yes, The Block Chainable with Legitimate Chain.")
                //Append A Block
                return (.chainableBlock, lastBlock, self.currentDifficultyAsNonceLeadingZeroLength)
            } else {
                /*
                 Block is NOT To Chain Next.
                 */
                Log("No, New Block is NOT Chained Cached Last Block.")
                if let secondaryCandidateAsDictionary = lastBlock.fetchSecondaryCandidate(),
                   let secondaryCandidateBlock = Block.block(from: secondaryCandidateAsDictionary, book: self, node: node, chainable: .storeAsSecondaryCandidateBlock) {
                    Log("As There is Secondary Candidate Block.")
                    LogEssential("Candidate Chain Chainable? \(previousBlockHash) == \(secondaryCandidateBlock.hashedString)")
                    if let secondaryCandidateBlockHashedString = secondaryCandidateBlock.hashedString, previousBlockHash.equal(secondaryCandidateBlockHashedString) {
                        /*
                         Lay Secondary Candidate Block First As The Block is Secondary Candidate Block's Next
                         
                         If Chain New Block to Secondary Candidate Block, and Remove Last Block.
                         */
                        LogEssential("Yes, The Block Chainable with Candidate Chain.")
                        return (.secondaryCandidateBlocksNext, secondaryCandidateBlock, secondaryCandidateBlock.nextDifficulty)
                    } else {
                        LogEssential("No")
                    }
                }
                Log(self.blocks.endIndex)
                /*
                 before last 2 block
                 →  before last block
                 last block
                 */
                let indexBeforeLastBlock = 2    //2 before it.
                let beforeLastBlock = self.blocks[self.blocks.endIndex - indexBeforeLastBlock]
                LogEssential("Should Store as Candidate Block? \(previousBlockHash) == \(beforeLastBlock.hashedString)")
                if let beforeLastBlockHashedString = beforeLastBlock.hashedString, self.blocks.endIndex >= indexBeforeLastBlock, previousBlockHash.equal(beforeLastBlockHashedString) {
                    /*
                     Chain to Second Last Block As The Block's Previous Block Hash.
                     
                     Function detect whether same previous block to chain the block.
                     */
                    LogEssential("Yes, The Block Store As Secondary Candidate Block.")
                    return (.storeAsSecondaryCandidateBlock, beforeLastBlock, beforeLastBlock.nextDifficulty)
                } else {
                    LogEssential("No, The Block to Trash as Do Not Apply to Legitimate Chain, Candidate Chain, New Candidate.")
                    //The Block to Trash.(Omit the Block.)
                    return (.omitBlock, Block(Null: ""), Int.max)
                }
            }
        }
        LogEssential("The Block to Trash as invalid last block in legitimate Chain.")
        return (.omitBlock, Block(Null: ""), Int.max)
    }
    
    public func makeNextDifficulty(blockDate: Date) -> Difficulty {
        Log()
        var currentDifficultyAsNonceLeadingZeroLength: Int = self.currentDifficultyAsNonceLeadingZeroLength.toInt
        if let lastBlockDate = self.lastBlock?.date {
            Log("\(lastBlockDate) - \(blockDate)")
            let intervalSeconds = lastBlockDate.timeIntervalSince(blockDate)   //As Seconds.
            Log("\(intervalSeconds) < \(Nonce.minimumSecondsInProofOfWorks)")
            if intervalSeconds < Nonce.minimumSecondsInProofOfWorks {
                Log("Under \(Nonce.minimumSecondsInProofOfWorks / 60) min. in Proof Of Work.")
                /*
                 Under {Nonce.minimumSecondsInProofOfWorks / 60} minutes,
                    then increment difficulty value.
                 
                 Bring Effect to More Difficult.
                 */
                Log("Difficulty-- \(currentDifficultyAsNonceLeadingZeroLength)")
                currentDifficultyAsNonceLeadingZeroLength += 1
                Log("Difficulty++ \(currentDifficultyAsNonceLeadingZeroLength)")
            }
        }
        Log(currentDifficultyAsNonceLeadingZeroLength)
        return currentDifficultyAsNonceLeadingZeroLength
    }
    
    /*
     Not In Use.
     Detect Same Signature Block In Cached Book.
     */
    private func isThereSameBlock(signature: Signature) -> Bool {
        Log()
        for block in blocks {
            if let havingSignature = block.signature, havingSignature.equal(signature) {
                return true
            }
        }
        return false
    }

    /*
     Content in parameters, it Should be use 'Data' rather than 'String'.
     */
    public func validate(signature: Signature, signer: Signer) -> Bool {
        Log()
        var validated = true
        blocks.forEach {
            if $0.validate(signature: signature, signer: signer) {
            } else {
                validated = false
            }
        }
        return validated
    }
    
    /*
     Library
         ブックをコンピュータに保存する
     */
    /*
     Store Book to Device's Storage.
     
     Format: Json
     */
    private let archivedDirectory = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first! + "/book/"
    private let archiveFile = "book.json"
    private var archiveFilePath: String {
        self.archivedDirectory + self.archiveFile
    }

    /*
     utf8 →Data
     */
    private var content: Data {
        var jsonString = """
{"signature":"\(self.signature.toString)",
"currentDifficultyAsNonceLeadingZeroLength":"\(self.currentDifficultyAsNonceLeadingZeroLength)"
"""
        jsonString += blocks.enumerated().reduce("") {
            var leadPadding = ""
            var trailPadding = ","
            if $1.offset == 0 {
                leadPadding = ",\"blocks\":["
            }
            if $1.offset == blocks.count - 1 {
                trailPadding = "]"
            }
            return $0 + leadPadding + ($1.element.content.utf8String ?? "") + trailPadding
        }
        jsonString += "}"
        let data = jsonString.utf8DecodedData
        if let data = data {
            return data
        }
        return Data.DataNull
    }
    
    public func recordLibrary() {
        Log()
        do {
            if !FileManager.default.fileExists(atPath: self.archivedDirectory) {
                do {
                    try FileManager.default.createDirectory(atPath: self.archivedDirectory, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    Log()
                }
            }
            let storeUrl = URL(fileURLWithPath: self.archiveFilePath)
            let jsonAsData = self.content
            Log("\(jsonAsData.utf8String ?? "")")
            try jsonAsData.append(to: storeUrl, truncate: true)
        } catch {
            Log("Save Json Error \(error)")
        }
    }

    public func isCached() -> Bool {
        Log()
        if !FileManager.default.fileExists(atPath: self.archiveFilePath) {
            Log("No Cached")
            return false
        }
        Log("Cached")
        return true
    }

    public func fetchLibrary() -> [String: String]? {
        Log()
        if self.isCached() {
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
