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
    /*
     Legitimate Chain
     
     Block array
     */
    public var blocks = [Block]()
    /*
     Candidate Chain
     
     2 dimensional Block array
        Key: Branched Previous Block's Hashed String or Block ID
        Value: [First Candidate][Block, ...], [Secondary Candidate][Block, ...]

     Swap Rule:
     Grow {4} Blocks in any Candidate Chain, then Swap Candidate Chain to Legitimate Chain at Branch started Point.
     
     Restrict:
     None Branch in Candidate Chain.
     */
    public var candidates = [String: [[Block]]]()
    public let candidateChainsMaximumForEachBranch = 10
    public let chainSwapRuledBlockCount = 4
    
    /*
     blocks
         blocks[arrayLength - 3]: before last 2 block
         blocks[arrayLength - 2]: before last block
         blocks[arrayLength - 1]: last block
     */
    public var lastBlock: Block? {
        self.blocks.last
    }
    public var beforeLastBlock: Block? {
        guard self.blocks.endIndex - 2 >= 0 else {
            return nil
        }
        return self.blocks[self.blocks.endIndex - 2]
    }
    public var signature: Signature
    /*
     Value Range is 0 - 512 (Nonce.bits)
     
     Default value is 16
     */
//    public var currentDifficultyAsNonceLeadingZeroLength: Difficulty

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
    public mutating func chain(block: Block, chainable: ChainableResult, previousBlock: Block, node: Node, branchHashString: HashedString? = nil, indexInBranchPoint: Int? = nil, indexInBranchChain: Int? = nil) {
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
            if block.validate(signature: signatureData, signer: signer, chainable: chainable, branchChainHash: branchHashString, indexInBranchChain: indexInBranchChain) {
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
                case .branchableBlock:
                    LogEssential("The Block Chained as Candidate Branch Chain.")
                    /*
                     if branch length (other word, contained Blocks Count) over {chainSwapRuledBlockCount}, Swap the Branch to Legitimate Chain at Branch Point.
                     */
                    guard let branchHashString = branchHashString, let indexInBranchPoint = indexInBranchPoint, let indexInBranchChain = indexInBranchChain else {
                        return
                    }
                    LogEssential(branchHashString.toString)
                    LogEssential(indexInBranchPoint)
                    LogEssential(indexInBranchChain)
                    LogEssential(self.candidates.count)
                    LogEssential(self.candidates[branchHashString.toString]?.count)
                    let branchHashedString = branchHashString.toString
                    LogEssential("\(self.candidates[branchHashedString]?.endIndex) == \(indexInBranchPoint)")
                    if indexInBranchChain == 0 {
                        /*
                         As Top Entry of The Branch.
                         */
                        LogEssential("Top Entry of The Branch Chain.")
                        self.candidates[branchHashedString]?.append([block])
                    } else {
                        LogEssential("There is Branch Chain in The Branch Point, Already")
                        self.candidates[branchHashedString]?[indexInBranchPoint] += [block]
                    }
//                        }
                    if let branchChainLength = self.candidates[branchHashedString]?[indexInBranchPoint].count, branchChainLength >= chainSwapRuledBlockCount {
                        LogEssential("Should Swap Branch to Legitimate Chain's Branch Point. \(branchHashedString)")
                        /*
                         Swap Branch to Legitimate Chain's Branch Point.
                         */
                        if let branchPointIndex = self.findBranchPointInLegitimateChain(branchHashedString: branchHashedString) {
                            LogEssential("Found Branched Point in Legitimate Chain.")
                            self.blocks = self.blocks[0...branchPointIndex] + (self.candidates[branchHashedString]?[indexInBranchPoint] ?? [])
                        } else {
                            LogEssential("Not Found Branched Point in Legitimate Chain.")
                        }
                        /*
                         Clear Branches named {branchHashedString}.
                         */
//                        self.candidates[branchHashedString] = [[Block]]()
                        self.candidates[branchHashedString] = nil
                    }
                case .chainableBlock:
                    /*
                     Block is To Chain Next.
                     New Block As Cached Last Block's Next.
                     */
                    LogEssential("The Block Chained in Legitimate Chain.")
                    //Append A Block
                    self.blocks += [block]
                    /*
                     過去３つより前の block hash を起点としたbranchを全て削除する
                     */
                    self.reduceBranch()
                case .omitBlock:
                    break
                }
                #if DEBUG
                print("After Block Chained")
                print("[Legitimate Chain]")
                if self.blocks.count == 0 {print("legitimate chain none")}
                for block in self.blocks.enumerated() {
                    print("legitimate chain \(block.offset): \(block.element.id) - \(block.element.hashedString) - \(block.element.difficultyAsNonceLeadingZeroLength) - \(block.element.nextDifficulty)", terminator: "\n")
                }
                print("[Candidate Chains]")
                if self.candidates.count == 0 {print("candidate branch chain none")}
                for branches in self.candidates {
                    print("Branch Point Hash: \(branches.key)", terminator: "\n")
                    for branch in branches.value.enumerated() {
                        print("Branch: \(branch.offset)")
                        for block in branch.element.enumerated() {
                            print("branch chain \(block.offset): \(block.element.id) - \(block.element.hashedString) - \(block.element.difficultyAsNonceLeadingZeroLength) - \(block.element.nextDifficulty)", terminator: "\n")
                        }
                    }
                }
                #endif
                Log()
                //Store to Json File.
                if chainable == .branchableBlock || chainable == .chainableBlock {
                    self.recordLibrary()
                }
            }
        }
    }
    
    public mutating func reduceBranch() {
        LogEssential()
        /*
         Block is Confirmed As There following 4 Blocks, Remove All Branch Chains Rooted Block Before Confirmed Block.

         Block Array in Legitimate Chain
         blocks[0]　←Confirmed
            [1]
            [2]
            [3]
            [4]
         candidates[{Branch Point 0}][0]
            [{Branch Point 0}][0][1]
            [{Branch Point 2}][0]
         
         ↓
         Add 1 Block in Legitimate Chain
         blocks[0]　←Confirmed
            [1]　←Confirmed
            [2]
            [3]
            [4]
            [5]
         candidates[{Branch Point 0}][0]
            [{Branch Point 0}][0][1]
            [{Branch Point 2}][0]
         
         ↓
         Reduced Branches
         blocks[0]　←Confirmed
            [1]　←Confirmed
            [2]
            [3]
            [4]
            [5]
         candidates[{Branch Point 2}][0]
         */
        LogEssential(self.blocks.endIndex)
        let blockBeforeConfirmedBlockIndex = self.blocks.endIndex - (self.chainSwapRuledBlockCount + 2)
        LogEssential(blockBeforeConfirmedBlockIndex)
        if blockBeforeConfirmedBlockIndex >= 0 {
            LogEssential()
            let block = self.blocks[blockBeforeConfirmedBlockIndex]
            if let blockHashedString = block.hashedString?.toString, let _ = self.candidates[blockHashedString] {
                /*
                 Delete Same Start Point Branch Chains, Entire Root.
                 */
                LogEssential(blockHashedString)
                self.candidates[blockHashedString] = nil
            }
        }
    }
    
    /*
     Find Chain Index in specific Branch, Max 10
     
     nil:
        Branch is full up to candidateChainsMaximumForEachBranch.
     */
    public mutating func chainIndexForEachBranch(block: Block) -> Int? {
        var candidateIndex: Int? = nil
        if let candidateChain = self.candidates[block.previousBlockHash.toString] {
            for candidateChainIndex in 0..<candidateChainsMaximumForEachBranch {
                if candidateChainIndex < candidateChain.count {
                    if candidateChain[candidateChainIndex].isEmpty {
                        //empty chain index
                        LogEssential("Empty Index in Branch named \(block.previousBlockHash.toString): \(candidateChainIndex)")
                        candidateIndex = candidateChainIndex
                    }
                }
            }
        } else {
            //branch is empty
            LogEssential("Empty in Branch named \(block.previousBlockHash.toString)")
            self.candidates[block.previousBlockHash.toString] = [[Block]]()
            candidateIndex = 0
        }
        return candidateIndex
    }

    /*
     Find Branch Hash Key and Index in Chainable Branch.
     
     if there is NOT Branch in candidate chain, make it.
     */
    public mutating func branchAndIndex(previousBlockHash: HashedString) -> (HashedString, Int, Int, Difficulty, Block)? {
        var candidateBranchHashString: String
        var indexInChainPoint: Int
        var indexInBranch: Int
        var nextDifficulty: Difficulty
        var previousBlock: Block
        /*
         Take Chain Point in each Branch Chain.
         */
        //self.candidates: [{Branch Started Block's Hash String}: [[Block], ...MAX 10]
        for branchs in self.candidates.enumerated() {
            let branchHashString = branchs.element.key
            let branchChains = branchs.element.value   //branchChains: [[Block], ...MAX 10]
//            for branchChain in branchChains {
            for branchChain in branchChains.enumerated() {
                //branchChain: [Block, ...MAX 4]
                if branchChain.element.endIndex < chainSwapRuledBlockCount {
                    //Found available Branch chain
                    LogEssential()
                    if let lastBlock = branchChain.element.last, let lastBlockHash = lastBlock.hashedString, lastBlockHash.equal(previousBlockHash) {
                        LogEssential()
                        candidateBranchHashString = branchHashString
                        nextDifficulty = lastBlock.nextDifficulty
                        previousBlock = lastBlock
                        indexInBranch = branchChain.element.endIndex
                        indexInChainPoint = branchChain.offset
                        LogEssential("Found Branch and Index. \(candidateBranchHashString) - \(indexInBranch)")
                        LogEssential("\(candidateBranchHashString) - \(indexInChainPoint) - \(indexInBranch) - \(nextDifficulty) - \(previousBlock.content.utf8String)")
                        return (candidateBranchHashString, indexInChainPoint, indexInBranch, nextDifficulty, previousBlock)
                    }
                }
            }
        }
        //There is NOT Branch named {previousBlockHash}.
        LogEssential("There is NOT Branch named \(previousBlockHash.toString)")
        /*
         Confirm Available as Branch Point in Legitimate Chain.
         */
        if let indexInLegitimateChain = self.findBranchPointInLegitimateChain(branchHashedString: previousBlockHash) {
            LogEssential("Found Available as Branch Point for \(previousBlockHash.toString) til before 4 last in Legitimate Chain")
            previousBlock = self.blocks[indexInLegitimateChain]
            nextDifficulty = self.blocks[indexInLegitimateChain].nextDifficulty
            self.candidates[previousBlockHash.toString] = [[Block]]()
            indexInChainPoint = 0
            indexInBranch = 0
            LogEssential("First Block in Branch named \(previousBlockHash.toString)")
            LogEssential("\(previousBlockHash) - \(indexInBranch) - \(nextDifficulty) - \(previousBlock.content.utf8String)")
            return (previousBlockHash, indexInChainPoint, indexInBranch, nextDifficulty, previousBlock)
        }
        return nil
    }
    
    public func findBranchPointInLegitimateChain(branchHashedString: HashedString) -> Int? {
        for block in self.blocks[(self.blocks.endIndex - self.chainSwapRuledBlockCount < 0 ? 0 : self.blocks.endIndex - self.chainSwapRuledBlockCount)...].enumerated() {
            Log(block.offset)
            if let blockHashedString = block.element.hashedString, blockHashedString.equal(branchHashedString) {
                Log("Found Branched Point. \(block.offset)")
                return block.offset
            }
            if block.offset > self.chainSwapRuledBlockCount {
                Log()
                break
            }
        }
        Log()
        return nil
    }
    
    public enum ChainableResult {
        case branchableBlock       //Block is To Chain in Branch Chain.
        case omitBlock          //The Block to Trash.(Omit the Block.
        case chainableBlock     //Block is To Chain in Legitimate Chain.
    }
    public mutating func chainable(previousBlockHash: HashedString, signatureForBlock: Signature, node: Node) -> (ChainableResult, Block, Difficulty, HashedString?, Int?, Int?) {
        Log("previousBlockHash: \(previousBlockHash)")
        #if DEBUG
        print("Pre Block Chained")
        print("[Legitimate Chain]")
        if self.blocks.count == 0 {print("legitimate chain none")}
        for block in self.blocks.enumerated() {
            print("legitimate chain \(block.offset): \(block.element.id) - \(block.element.hashedString) - \(block.element.difficultyAsNonceLeadingZeroLength) - \(block.element.nextDifficulty)", terminator: "\n")
        }
        print("[Candidate Chains]")
        if self.candidates.count == 0 {print("candidate branch chain none")}
        for branches in self.candidates {
            print("Branch Point Hash: \(branches.key)", terminator: "\n")
            for branch in branches.value.enumerated() {
                print("Branch: \(branch.offset)")
                for block in branch.element.enumerated() {
                    print("branch chain \(block.offset): \(block.element.id) - \(block.element.hashedString) - \(block.element.difficultyAsNonceLeadingZeroLength) - \(block.element.nextDifficulty)", terminator: "\n")
                }
            }
        }
        #endif
        let lastBlock = self.lastBlock ?? Block.genesis
        Log(self.blocks.count)
        guard let lastBlockSignature = lastBlock.signature else {
            LogEssential("The Block to Trash as Signature Invalid.")
            return (.omitBlock, Block(Null: ""), Int.max, nil, nil, nil)
        }
        if lastBlockSignature.equal(signatureForBlock) {
            /*
             Duplicate Block
             */
            LogEssential("The Block to Trash as Signature Duplicate.")
            return (.omitBlock, Block(Null: ""), Int.max, nil, nil, nil)
        }
        
        LogEssential("Legitimate Chain Chainable? \(previousBlockHash) != \(lastBlock.hashedString)")
        if let lastBlockHashedString = lastBlock.hashedString {
            if previousBlockHash.equal(lastBlockHashedString) {
                /*
                 Block Chainable to Legitimate Chain.
                 */
                LogEssential("Yes, The Block Chainable with Legitimate Chain.")
                //Append A Block
                return (.chainableBlock, lastBlock, lastBlock.nextDifficulty, nil, nil, nil)
            }
            /*
             Block Not Chainable to Legitimate Chain.
             */
            LogEssential("No, New Block is NOT Chainable to Legitimate Chain.")
            LogEssential("So, Should Store as Candidate any Branch Chain? \(previousBlockHash)")
            if let (branchHash, indexInChainPoint, indexInBranchChain, nextDifficulty, previousBlock) = self.branchAndIndex(previousBlockHash: previousBlockHash) {
                LogEssential("Yes, The Block Store As Candidate Branch named \(branchHash).")
                return (.branchableBlock, previousBlock, nextDifficulty, branchHash, indexInChainPoint, indexInBranchChain)
            }
            LogEssential("No, The Block Not Chainable to Candidate Branch Chain as Block hash: \(previousBlockHash).")
            LogEssential("The Block to Trash as Do Not Apply to Legitimate Chain, Candidate Branch Chains.")
            //The Block to Trash.(Omit the Block.)
            return (.omitBlock, Block(Null: ""), Int.max, nil, nil, nil)
        }
        LogEssential("The Block to Trash as invalid last block in legitimate Chain.")
        return (.omitBlock, Block(Null: ""), Int.max, nil, nil, nil)
    }

    /*
     As Make New Block,
     Take Next Difficulty Value for each Chainable.
     
     previousBlockHash:
        if chainable is .branchableBlock, this is branchHash as Candidate Branch Chain's key.
     */
    public func takeNextDifficulty(for chainable: ChainableResult, previousBlockHash: HashedString?, indexInBranchPoint: Int?, indexInBranchChain: Int?, branchPoint: HashedString?) -> Difficulty? {
        LogEssential(chainable)
        LogEssential(previousBlockHash)
        LogEssential(indexInBranchChain)
        LogEssential(indexInBranchPoint)
        LogEssential(branchPoint)
        switch chainable {
        case .branchableBlock:
            if let previousBlockHash = previousBlockHash, let indexInBranchChain = indexInBranchChain, let indexInBranchPoint = indexInBranchPoint, let branchHashedString = branchPoint?.toString {
                if indexInBranchChain == 0 {
                    LogEssential("No Entries in the Branch Chain cause Top Block in the Branch.")
                    if let indexInLegitimateChain = findBranchPointInLegitimateChain(branchHashedString: previousBlockHash) {
                        let nextDifficulty = self.blocks[indexInLegitimateChain].nextDifficulty
                        LogEssential(nextDifficulty)
                        return nextDifficulty
                    }
                } else if indexInBranchChain > 0 {
                    LogEssential("There is Entries in the Branch Chain cause 2nd and later Block in the Branch. \(branchHashedString)")
                    LogEssential(indexInBranchPoint)
                    LogEssential(self.candidates[branchHashedString]?.count)
                    guard let branchChains = self.candidates[branchHashedString] else {
                        return nil
                    }
                    let nextDifficulty = branchChains[indexInBranchPoint].last?.nextDifficulty
                    LogEssential(nextDifficulty)
                    return nextDifficulty
                } else {
                    return nil
                }
            }
        case .chainableBlock:
            if self.blocks.count == 0 {
                return Int.minDifficulty
            } else {
                guard let nextDifficulty = self.lastBlock?.nextDifficulty else {
                    return nil
                }
                return nextDifficulty
            }
        case .omitBlock:
            return nil
        }
        return nil
    }
    public func takeLastBlockDate(for chainable: ChainableResult, branchChainHash: HashedString?, indexInBranchPoint: Int?, indexInBranchChain: Int?) -> Date? {
        LogEssential(chainable)
        LogEssential(branchChainHash)
        LogEssential(indexInBranchPoint)
        LogEssential(indexInBranchChain)
        switch chainable {
        case .branchableBlock:
            guard let branchChainHash = branchChainHash?.toString, let indexInBranchChain = indexInBranchChain, let indexInBranchPoint = indexInBranchPoint else {
                return nil
            }
            if indexInBranchChain == 0 {
                LogEssential("No Entries in the Branch Chain.")
                if let indexInLegitimateChain = findBranchPointInLegitimateChain(branchHashedString: branchChainHash) {
                    let lastBlockDate = self.blocks[indexInLegitimateChain].date
                    LogEssential(lastBlockDate)
                    return lastBlockDate
                }
            } else {
                guard let branchChains = self.candidates[branchChainHash] else {
                    LogEssential("candidates branch \(branchChainHash) not found.")
                    return nil
                }
                let lastBlockDate = branchChains[indexInBranchPoint].last?.date
                LogEssential(lastBlockDate)
                return lastBlockDate
            }
        case .chainableBlock:
            let lastBlockDate = self.lastBlock?.date
            return lastBlockDate
        case .omitBlock:
            return nil
        }
        return nil
    }
    public func makeNextDifficulty(blockDate: Date, chainable: ChainableResult, previousBlockHash: HashedString?, indexInBranchPoint: Int?, branchPoint: HashedString?, indexInBranchChain: Int?) -> Difficulty? {
        LogEssential(chainable)
        guard var currentDifficultyAsNonceLeadingZeroLength: Int = self.takeNextDifficulty(for: chainable, previousBlockHash: previousBlockHash, indexInBranchPoint: indexInBranchPoint, indexInBranchChain: indexInBranchChain, branchPoint: branchPoint)?.toInt else {
            return nil
        }
        var lastBlockDate = self.takeLastBlockDate(for: chainable, branchChainHash: branchPoint, indexInBranchPoint: indexInBranchPoint, indexInBranchChain: indexInBranchChain)
        LogEssential("What will compare for lastBlockDate in make next difficulty.: \(lastBlockDate)")
        if let lastBlockDate = lastBlockDate {
            Log("\(lastBlockDate.utcTimeString) - \(blockDate.utcTimeString)")
            let intervalSeconds = blockDate.timeIntervalSince(lastBlockDate)   //As Seconds.
            Log("\(intervalSeconds) < \(Nonce.minimumSecondsInProofOfWorks)")
            if intervalSeconds < Nonce.minimumSecondsInProofOfWorks {
                LogEssential("Under \(Nonce.minimumSecondsInProofOfWorks / 60) min. in Proof Of Work cause Increment Difficulty.")
                /*
                 Under {Nonce.minimumSecondsInProofOfWorks / 60} minutes,
                    then increment difficulty value.
                 
                 Bring Effect to More Difficult.
                 */
                LogEssential("Difficulty-- \(currentDifficultyAsNonceLeadingZeroLength)")
                currentDifficultyAsNonceLeadingZeroLength += 1
                LogEssential("Difficulty++ \(currentDifficultyAsNonceLeadingZeroLength)")
            } else {
                LogEssential("Over \(Nonce.minimumSecondsInProofOfWorks / 60) min. in Proof Of Work, then let Difficulty be.")
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
    public func validate(signature: Signature, signer: Signer, branchChainHash: HashedString?, indexInBranchChain: Int?) -> Bool {
        Log()
        var validated = true
        blocks.forEach {
            if $0.validate(signature: signature, signer: signer, branchChainHash: branchChainHash, indexInBranchChain: indexInBranchChain) {
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
//        var jsonString = """
//{"signature":"\(self.signature.toString)",
//"currentDifficultyAsNonceLeadingZeroLength":"\(self.currentDifficultyAsNonceLeadingZeroLength)"
//"""
        var jsonString = """
{"signature":"\(self.signature.toString)"
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
