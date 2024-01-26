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
    public mutating func chain(block: Block, chainable: ChainableResult, previousBlock: Block, node: Node, branchHashString: HashedString? = nil, indexInBranch: Int? = nil) {
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
            if block.validate(signature: signatureData, signer: signer, chainable: chainable, branchChainHash: branchHashString, indexInBranchChain: indexInBranch) {
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
                    LogEssential("The Block Chained as Candidate Branch Chain.")
                    /*
                     if branch length (other word, contained Blocks Count) over {chainSwapRuledBlockCount}, Swap the Branch to Legitimate Chain at Branch Point.
                     */
                    LogEssential(branchHashString?.toString)//nil #now
                    LogEssential(indexInBranch)
                    if let branchHashedString = branchHashString?.toString, let candidateIndex = indexInBranch {
                        LogEssential("\(self.candidates[branchHashedString]?.endIndex) == \(candidateIndex)")
//                        if let branchChain = self.candidates[branchHashedString], branchChain.isEmpty {
//                            self.candidates[branchHashedString] = [[Block]]()
                        if self.candidates[branchHashedString]?.endIndex == candidateIndex {
                            self.candidates[branchHashedString]?.append([block])
                        } else {
                            self.candidates[branchHashedString]?[candidateIndex] += [block]
                        }
//                        }
                        if let branchChainLength = self.candidates[branchHashedString]?[candidateIndex].count, branchChainLength >= chainSwapRuledBlockCount {
                            LogEssential("Should Swap Branch to Legitimate Chain's Branch Point. \(branchHashedString)")
                            /*
                             Swap Branch to Legitimate Chain's Branch Point.
                             */
                            if let branchPointIndex = self.findBranchPointInLegitimateChain(branchHashedString: branchHashedString) {
                                LogEssential("Found Branched Point in Legitimate Chain.")
                                self.blocks = self.blocks[0...branchPointIndex] + (self.candidates[branchHashedString]?[candidateIndex] ?? [])
                            } else {
                                LogEssential("Not Found Branched Point in Legitimate Chain.")
                            }
                            /*
                             Clear Branches named {branchHashedString}.
                             */
                            self.candidates[branchHashedString] = [[Block]]()
                        }
                    }
//                case .storeAsSecondaryCandidateBlock:
//                    /*
//                     Chain to Second Last Block As The Block's Previous Block Hash.
//                     
//                     Function detect whether same previous block to chain the block.
//                     */
//                    LogEssential("The Block Store As Secondary Candidate Block in Candidate Chain.")
//                    LogEssential(block.hashedString)
//                    LogEssential(block.content.utf8String)
//                    /*
//                     Find Candidate Chain Index for the Branch.
//                     */
//                    let candidateIndex = self.chainIndexForEachBranch(block: block)
//                    /*
//                     Store Block in Candidate Chain
//                     */
//                    if let candidateIndex = candidateIndex {
//                        self.candidates[block.previousBlockHash.toString]?[candidateIndex] += [block]
//                        LogEssential("Block Chained in named \(block.previousBlockHash.toString) Candidate: \(self.candidates[block.previousBlockHash.toString])")
//                    } else {
//                        LogEssential("Over Max in the Branch in Candidate Chain cause Omit.")
//                    }
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
//                    Log(self.lastBlock)
                case .omitBlock:
                    break
                }
                #if DEBUG
                print("After Block Chained")
                print("[Legitimate Chain]")
                if self.blocks.count == 0 {print("legitimate chain none")}
                for block in self.blocks.enumerated() {
                    print("legitimate chain \(block.offset): \(block.element.hashedString) - \(block.element.difficultyAsNonceLeadingZeroLength) - \(block.element.nextDifficulty)", terminator: "\n")
                }
//                if self.blocks.count > 0 {self.lastBlock?.isCachedForSecondaryCandidate()}
                /*
                 Reveal Secondary Candidate Block's Hash
                 */
//                LogEssential("--Reveal Secondary Candidate Block's Hash")
//                if let secondaryCandidateAsDictionary = block.fetchSecondaryCandidate(),
////                   let secondaryCandidateBlock = Block.block(from: secondaryCandidateAsDictionary, book: self, node: node, chainable: .storeAsSecondaryCandidateBlock) {
//                   let secondaryCandidateBlock = Block.block(from: secondaryCandidateAsDictionary, book: self, chainable: .storeAsSecondaryCandidateBlock) {
//                    LogEssential("Have Stored secondaryCandidateBlockHash: \(secondaryCandidateBlock.hashedString) - \(secondaryCandidateBlock.difficultyAsNonceLeadingZeroLength) - \(secondaryCandidateBlock.nextDifficulty)")
//                    LogEssential(secondaryCandidateBlock.content.utf8String)
//                }
//                LogEssential("++Reveal Secondary Candidate Block's Hash")
                print("[Candidate Chains]")
                if self.candidates.count == 0 {print("candidate branch chain none")}
                for branches in self.candidates {
                    print("Branches Started Hash: \(branches.key)", terminator: "\n")
                    for branch in branches.value.enumerated() {
                        print("Candidate Branch: \(branch.offset)")
                        for block in branch.element.enumerated() {
                            print("branch chain \(block.offset): \(block.element.hashedString) - \(block.element.difficultyAsNonceLeadingZeroLength) - \(block.element.nextDifficulty)", terminator: "\n")
                        }
                    }
                }
                #endif
                Log()
                //Store to Json File.
                if chainable == .secondaryCandidateBlocksNext || chainable == .chainableBlock {
                    self.recordLibrary()
                }
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
    public mutating func branchAndIndex(previousBlockHash: HashedString) -> (HashedString, Int, Difficulty, Block)? {
        var candidateBranchHashString: String
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
            for branchChain in branchChains {
                //branchChain: [Block, ...MAX 4]
                if branchChain.endIndex < chainSwapRuledBlockCount {
                    //Found available Branch chain
                    LogEssential()
                    if let lastBlock = branchChain.last, let lastBlockHash = lastBlock.hashedString, lastBlockHash.equal(previousBlockHash) {
                        LogEssential()
                        candidateBranchHashString = branchHashString
                        nextDifficulty = lastBlock.nextDifficulty
                        previousBlock = lastBlock
                        indexInBranch = branchChain.endIndex
                        LogEssential("Found Branch and Index. \(candidateBranchHashString) - \(indexInBranch)")
                        LogEssential("\(candidateBranchHashString) - \(indexInBranch) - \(nextDifficulty) - \(previousBlock.content.utf8String)")
                        return (candidateBranchHashString, indexInBranch, nextDifficulty, previousBlock)
                    }
                }
            }
        }
        //There is NOT Branch named {previousBlockHash}.
        LogEssential("There is NOT Branch named \(previousBlockHash.toString)")
        /*
         Take Branch Point in Legitimate Chain.
         */
        if let indexInLegitimateChain = self.findBranchPointInLegitimateChain(branchHashedString: previousBlockHash) {
            //Top branch as Start
            LogEssential("Found Available Branch Point for \(previousBlockHash.toString) til before 4 last in Legitimate Chain")
            previousBlock = self.blocks[indexInLegitimateChain]
            nextDifficulty = self.blocks[indexInLegitimateChain].nextDifficulty
            self.candidates[previousBlockHash.toString] = [[Block]]()
            indexInBranch = 0
            LogEssential("First Block in Branch named \(previousBlockHash.toString)")
            LogEssential("\(previousBlockHash) - \(indexInLegitimateChain) - \(nextDifficulty) - \(previousBlock.content)")
            return (previousBlockHash, indexInLegitimateChain, nextDifficulty, previousBlock)
        }
        return nil
    }
    
    public func findBranchPointInLegitimateChain(branchHashedString: HashedString) -> Int? {
//        for block in self.blocks.reversed().enumerated() {
        for block in self.blocks[(self.blocks.endIndex - self.chainSwapRuledBlockCount < 0 ? 0 : self.blocks.endIndex - self.chainSwapRuledBlockCount)...].enumerated() {
            LogEssential(block.offset)
            if let blockHashedString = block.element.hashedString, blockHashedString.equal(branchHashedString) {
                LogEssential("Found Branched Point. \(block.offset)")
                return block.offset
            }
            if block.offset > self.chainSwapRuledBlockCount {
                LogEssential()
                break
            }
        }
        LogEssential()
        return nil
    }
    
    public enum ChainableResult {
        case secondaryCandidateBlocksNext       //Block is Secondary Candidate Block's Next.
//        case storeAsSecondaryCandidateBlock     //Store As Secondary Candidate Block.
        case omitBlock          //The Block to Trash.(Omit the Block.
        case chainableBlock     //Block is To Chain Next.
    }
    public mutating func chainable(previousBlockHash: HashedString, signatureForBlock: Signature, node: Node) -> (ChainableResult, Block, Difficulty, HashedString?, Int?) {
        Log("previousBlockHash: \(previousBlockHash)")
        #if DEBUG
        print("Pre Block Chained")
        print("[Legitimate Chain]")
        if self.blocks.count == 0 {print("legitimate chain none")}
        for block in self.blocks.enumerated() {
            print("legitimate chain \(block.offset): \(block.element.hashedString) - \(block.element.difficultyAsNonceLeadingZeroLength) - \(block.element.nextDifficulty)", terminator: "\n")
        }
        print("[Candidate Chains]")
        if self.candidates.count == 0 {print("candidate branch chain none")}
        for branches in self.candidates {
            print("Branch Started Hash: \(branches.key)", terminator: "\n")
            for branch in branches.value.enumerated() {
                print("Candidate Branch: \(branch.offset)")
                for block in branch.element.enumerated() {
                    print("branch chain \(block.offset): \(block.element.hashedString) - \(block.element.difficultyAsNonceLeadingZeroLength) - \(block.element.nextDifficulty)", terminator: "\n")
                }
            }
        }
        #endif
        let lastBlock = self.lastBlock ?? Block.genesis
        Log(self.blocks.count)
        guard let lastBlockSignature = lastBlock.signature else {
            LogEssential("The Block to Trash as Signature Invalid.")
            return (.omitBlock, Block(Null: ""), Int.max, nil, nil)
        }
        if lastBlockSignature.equal(signatureForBlock) {
            /*
             Duplicate Block
             */
            LogEssential("The Block to Trash as Signature Duplicate.")
            return (.omitBlock, Block(Null: ""), Int.max, nil, nil)
        }
        
        LogEssential("Legitimate Chain Chainable? \(previousBlockHash) != \(lastBlock.hashedString)")
        if let lastBlockHashedString = lastBlock.hashedString {
            if previousBlockHash.equal(lastBlockHashedString) {
                /*
                 Block Chainable to Legitimate Chain.
                 */
                LogEssential("Yes, The Block Chainable with Legitimate Chain.")
                //Append A Block
                //                return (.chainableBlock, lastBlock, self.currentDifficultyAsNonceLeadingZeroLength)
                return (.chainableBlock, lastBlock, lastBlock.nextDifficulty, nil, nil)
            }
            /*
             Block Not Chainable to Legitimate Chain.
             */
            Log("No, New Block is NOT Chainable to Legitimate Chain.")
            //                if let branchChains = self.candidates[previousBlockHash.toString], branchChains.count > 0 {
            //                    Log("There is The Branch Chain for \(previousBlockHash).")
            //                    for branchChain in branchChains.enumerated() {
            //                        LogEssential("Chainable to Branch Chain? \(previousBlockHash) == \(branchChain.element.last?.hashedString)")
            //                        if let lastBlockInBranchChain = branchChain.element.last, let lastBlockHash = lastBlockInBranchChain.hashedString, previousBlockHash.equal(lastBlockHash) {
            //                            /*
            //                             Lay Secondary Candidate Block First As The Block is Secondary Candidate Block's Next
            //
            //                             If Chain New Block to Secondary Candidate Block, and Remove Last Block.
            //                             */
            //                            let nextDifficulty = lastBlockInBranchChain.nextDifficulty
            //                            LogEssential("Yes, The Block Chainable with Branch Chain. \(lastBlockHash)[\(branchChain.offset)] - \(nextDifficulty)")
            //                            return (.secondaryCandidateBlocksNext, lastBlockInBranchChain, nextDifficulty, branchChain.offset)
            //                        }
            //                    }
            //                }
            LogEssential("So, Should Store as Candidate any Branch Block? \(previousBlockHash)")
            if let (branchHash, indexInBranchChain, nextDifficulty, previousBlock) = self.branchAndIndex(previousBlockHash: previousBlockHash) {
                LogEssential("Yes, The Block Store As Candidate Branch Block named \(branchHash).")
                return (.secondaryCandidateBlocksNext, previousBlock, nextDifficulty, branchHash, indexInBranchChain)
            }
            LogEssential("No, The Block Not Chainable to Candidate Branch Chain as Block hash: \(previousBlockHash).")
//            Log(self.blocks.endIndex)
            /*
             before last 2 block
             →  before last block
             last block
             */
            //                let indexBeforeLastBlock = 2    //2 before it.
            //                let beforeLastBlock = self.blocks[self.blocks.endIndex - indexBeforeLastBlock]
            //                LogEssential("Should Store as Candidate Block? \(previousBlockHash) == \(self.beforeLastBlock?.hashedString)")
            //                if let beforeLastBlock = self.beforeLastBlock, let beforeLastBlockHashedString = beforeLastBlock.hashedString, previousBlockHash.equal(beforeLastBlockHashedString) {
            //                    /*
            //                     Chain to Second Last Block As The Block's Previous Block Hash.
            //
            //                     Function detect whether same previous block to chain the block.
            //                     */
            //                    LogEssential("Yes, The Block Store As Secondary Candidate Block.")
            //                    return (.storeAsSecondaryCandidateBlock, beforeLastBlock, beforeLastBlock.nextDifficulty, nil)
            //                } else {
            LogEssential("No, The Block to Trash as Do Not Apply to Legitimate Chain, Candidate Branch Chains.")
            //The Block to Trash.(Omit the Block.)
            return (.omitBlock, Block(Null: ""), Int.max, nil, nil)
            //                }
        }
        LogEssential("The Block to Trash as invalid last block in legitimate Chain.")
        return (.omitBlock, Block(Null: ""), Int.max, nil, nil)
    }

    /*
     As Make New Block,
     Take Next Difficulty Value for each Chainable.
     
     previousBlockHash:
        if chainable is .secondaryCandidateBlocksNext, this is branchHash as Candidate Branch Chain's key.
     */
    public func takeNextDifficulty(for chainable: ChainableResult, previousBlockHash: HashedString?, indexInBranch: Int?) -> Difficulty? {
//        var currentDifficultyAsNonceLeadingZeroLength: Difficulty?
        LogEssential(chainable)
        LogEssential(previousBlockHash)
        LogEssential(indexInBranch)
        switch chainable {
        case .secondaryCandidateBlocksNext:
//            guard let secondaryCandidateAsDictionary = self.lastBlock?.fetchSecondaryCandidate(),
//               let secondaryCandidateBlock = Block.block(from: secondaryCandidateAsDictionary, book: self, chainable: .storeAsSecondaryCandidateBlock) else {
//                return nil
//            }
//            guard let previousBlockHash = previousBlockHash, let indexInBranch = indexInBranch else {
            guard let previousBlockHash = previousBlockHash else {
                return nil
            }
//            if let branchChain = self.candidates[previousBlockHash.toString], branchChain.isEmpty {
            if let indexInBranch = indexInBranch {
                if indexInBranch == 0 {
                    LogEssential("No Entries in the Branch Chain cause Top Block in the Branch.")
                    if let indexInLegitimateChain = findBranchPointInLegitimateChain(branchHashedString: previousBlockHash) {
                        let nextDifficulty = self.blocks[indexInLegitimateChain].nextDifficulty
                        LogEssential(nextDifficulty)
                        return nextDifficulty
                    }
                } else if indexInBranch > 0 {
                    let branchHash = previousBlockHash
                    LogEssential("There is Entries in the Branch Chain cause 2nd and later Block in the Branch. \(branchHash.toString)")
                    let branchHashedString = branchHash.toString
//                    if self.candidates[branchHashedString]?.endIndex == indexInBranch {
//                        let nextDifficulty = self.candidates[branchHashedString]?
//                    } else {
                    LogEssential(indexInBranch)
                    LogEssential(self.candidates[branchHashedString]?.count)
                    guard let branchChains = self.candidates[branchHashedString] else {
//                        self.candidates[branchHashedString] = [[Block]]()
                        return nil
                    }
                    let nextDifficulty = branchChains[indexInBranch - 1].last?.nextDifficulty
                    LogEssential(nextDifficulty)
                    return nextDifficulty
//                    }
//                    let nextDifficulty = self.candidates[previousBlockHash.toString]?[indexInBranch].last?.nextDifficulty
//                    LogEssential(nextDifficulty)
//                    return nextDifficulty
                } else {
                    return nil
                }
            }
//        case .storeAsSecondaryCandidateBlock:
//            guard let nextDifficulty = self.beforeLastBlock?.nextDifficulty else {
//                return nil
//            }
//            self.blocks
//            currentDifficultyAsNonceLeadingZeroLength = nextDifficulty
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
    public func takeLastBlockDate(for chainable: ChainableResult, branchChainHash: HashedString?, indexInBranchChain: Int?) -> Date? {
//        var lastBlockDate: Date?
        switch chainable {
        case .secondaryCandidateBlocksNext:
//            guard let secondaryCandidateAsDictionary = self.lastBlock?.fetchSecondaryCandidate(),
//               let secondaryCandidateBlock = Block.block(from: secondaryCandidateAsDictionary, book: self, chainable: .secondaryCandidateBlocksNext) else {
//                return nil
//            }
            guard let branchChainHash = branchChainHash?.toString, let indexInBranchChain = indexInBranchChain else {
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
                let secondaryCandidateBlock = self.candidates[branchChainHash]?[indexInBranchChain - 1].last
                let lastBlockDate = secondaryCandidateBlock?.date
                return lastBlockDate
            }
//        case .storeAsSecondaryCandidateBlock:
//            lastBlockDate = self.beforeLastBlock?.date
        case .chainableBlock:
            let lastBlockDate = self.lastBlock?.date
            return lastBlockDate
        case .omitBlock:
            return nil
        }
        return nil
    }
    public func makeNextDifficulty(blockDate: Date, chainable: ChainableResult, previousBlockHash: HashedString?, indexInBranch: Int?) -> Difficulty? {
//        var currentDifficultyAsNonceLeadingZeroLength: Int = self.currentDifficultyAsNonceLeadingZeroLength.toInt
        LogEssential(chainable)
        guard var currentDifficultyAsNonceLeadingZeroLength: Int = self.takeNextDifficulty(for: chainable, previousBlockHash: previousBlockHash, indexInBranch: indexInBranch)?.toInt else {
            return nil
        }
        var lastBlockDate = self.takeLastBlockDate(for: chainable, branchChainHash: previousBlockHash, indexInBranchChain: indexInBranch)
//        if let lastBlockDate = self.lastBlock?.date {
        if let lastBlockDate = lastBlockDate {
            Log("\(lastBlockDate.utcTimeString) - \(blockDate.utcTimeString)")
//            let intervalSeconds = lastBlockDate.timeIntervalSince(blockDate)   //As Seconds.
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
//    public func validate(signature: Signature, signer: Signer) -> Bool {
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
