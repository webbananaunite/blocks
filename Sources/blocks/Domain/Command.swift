//
//  Command.swift
//  blocks
//
//  Created by よういち on 2023/08/16.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation
import overlayNetwork

public enum Command: String, CommandProtocol {
    //Block chain
    case publishTransaction = "PT"
    case publishTransactionReply = "PT_"
    case publishBlock = "PB"
    case publishBlockReply = "PB_"
    
    /*
     Paper: ライトノードの実装
     自分が最長のチェーンであると確信するまでネットワーク・ノードにクエリを実行することで取得
     #now
     */
    case fetchBlock = "FB"          //#now block取得コマンドを実装する
    case fetchBlockReply = "FB_"
    /*
     Paper: 無効なブロックアラート送信
     無効なブロックを検出したときにネットワーク ノードからのアラート
     #now
     ↓
     受信したら
     完全なブロックとアラートされたトランザクションをダウンロードして不整合を確認するように促すことです。
     #now
     
     */
    case invalidBlock = "IV"
    case invalidBlockReply = "IV_"

    case other = "ZZ"

    public static func command(_ command: String) -> Command {
        switch command {
            /*
             Block chain
             */
        case "PT":
            return .publishTransaction
        case "PT_":
            return .publishTransactionReply
        case "PB":
            return .publishBlock
        case "PB_":
            return .publishBlockReply
        default:
            return .other
        }
    }
    
    public func command(_ command: String) -> CommandProtocol {
        switch command {
            /*
             Block chain
             */
        case "PT":
            return Command.publishTransaction
        case "PT_":
            return Command.publishTransactionReply
        case "PB":
            return Command.publishBlock
        case "PB_":
            return Command.publishBlockReply
        default:
            return Command.other
        }
    }

    public static func rawValue(_ command: CommandProtocol) -> String {
        switch command {
            //Block chain
        case publishTransaction:
            return "PT"
        case publishTransactionReply:
            return "PT_"
        case publishBlock:
            return "PB"
        case publishBlockReply:
            return "PB_"

        default:
            return ""
        }
    }
    
    /*
     nil: No Fixed Operands Count.
     */
    func allowedOperandsCountRange() -> Range<Int>? {
        switch self {
            //Block chain
        case .publishTransaction:
            return 4..<99
        case .publishTransactionReply:
            return nil
        case .publishBlock:
            return 6..<99
        case .publishBlockReply:
            return nil
        case .fetchBlock:
            return nil
        case .fetchBlockReply:
            return nil
        case .invalidBlock:
            return nil
        case .invalidBlockReply:
            return nil
        case .other:
            return nil
        }
    }
    
    public func receive(node: inout any NodeProtocol, operands: String, from fromNodeIp: String, token: String) -> String? {
        LogEssential("\(self.rawValue) \(operands) \(token) From: \(fromNodeIp) in Premium Command.")
        let operandArray = operandTakeApart(operands: operands)
        Log(operandArray)
        Log("\(operandArray.count) : \(self.allowedOperandsCountRange())")
        guard let allowedRange = self.allowedOperandsCountRange(), allowedRange ~= operandArray.count else {
            Log("Operands Count Over Range")
            return nil
        }

        var doneAllFollowingJobs = true /* Use Only Reply Command */
        if self.isReply(), let _ = Command(rawValue: self.sendCommand) { Log()
            //Mark dequeue flag on it's status.
            let (_, _) = node.deQueueWithType(token: token, type: [.local, .delegate])
            let (updatedJob, _) = node.setJobResult(token: token, type: [.local, .delegate], result: operands) // **job result is overwritten following code possibly.
            
            /*
             Detect done ALL following(Chained) jobs.
             */
            if let chainedJobs = node.fetchFollowingJobs(token: token) {
                Log()
                let runningJob = chainedJobs.filter {
                    $0.status != .dequeued
                }.first
                doneAllFollowingJobs = runningJob == nil ? true : false
            }
            Log(doneAllFollowingJobs)
            node.printQueue(job: updatedJob)
        } else { Log()
            /*
             New Job
             
             Delegated by a node(other or own).
             Token use received token, the job token is not generated anew.
             */
            node.enQueue(job: Job(command: self, operand: operands, from: fromNodeIp, to: node.getIp, type: .delegated, token: token))
            node.printQueue()
        }
        Log()
        
        switch self {
            /*
             Block chain
             */
        case .publishBlock :    //MARK: publishBlock
            LogEssential("Do \(self.rawValue)  From: \(fromNodeIp)")
            Log("publishBlock")
            /*
             Operands
             
             0: type
             1: date
             2: blockAsJsonString
             3: publickey base64 encoded
             4: maker dht address
             5: nonce as hexadecimal
             */
            let type = operandArray[0]
            let date = operandArray[1]
            let blockAsJsonString = operandArray[2]  //context  x transactions as json string
            /*
             if use Compressed Operand.
             #pending
             */
//            var transactionsAsJsonArrayString = ""
//            if let compressedData = operandArray[1].base64DecodedData {  //base64 →Data
//                let compressedNSData = NSData(data: compressedData)
//                guard let data: Data = try? compressedNSData.decompressed(using: .zlib) as Data else {
//                    fatalError("Fail to Decompress Data")
//                }
//                if let utf8String = data.utf8String { //Data →utf8
//                    transactionsAsJsonArrayString = utf8String
//                }
//            }
//            Log(transactionsAsJsonArrayString)
            let base64EncodedPublicKeyStringForBlock = operandArray[3]  //block maker's public key
            let makerDhtAddressAsHexString = operandArray[4]
            let nonceAsHexadecimal = operandArray[5]
            Log("date: \(date)")
            Log("publicKey(Block): \(base64EncodedPublicKeyStringForBlock)")
            Log("nonceAsHexadecimal: \(nonceAsHexadecimal)")
            
            /*
             Blockを受け取った（先行Blockの初回）
             
             parameter　→ Contents(json配列) → Transaction にして
             ↓
             New Block.transactions　にまとめる
             ↓
             自分の Book にプライム候補として格納する
             
             Paper:
             ノードがブロックを受信しなかった場合、次のブロックを受信し、ブロックを逃したことに気付いたときに、ノードはブロックを要求します。
             #now
             
             */
//             let nonceAsData = nonceAsHexadecimal.hexadecimalDecodedData
//            Log(nonceAsData)
//            guard let blockAsDictionary = blockAsJsonString.jsonToAnyDictionary else{return nil}
//            Log(blockAsDictionary)
//                let transactions = blockAsDictionary["transactions"] as? [[String : Any]]
//            Log(transactions)
//                let publicKeyForBlockAsData = base64EncodedPublicKeyStringForBlock.base64DecodedData
//            Log(publicKeyForBlockAsData)
//                let signatureForBlock = blockAsDictionary["signature"] as? String
//            Log(signatureForBlock)
//                let id = blockAsDictionary["id"] as? String
//            Log(id)
//                let candidateNextDifficulty = blockAsDictionary["nextDifficulty"] as? String
//            Log(candidateNextDifficulty)
//            let candidateNextDifficultyAsInt = Int(candidateNextDifficulty ?? "-1")
//            Log(candidateNextDifficultyAsInt)
//                let previousBlockHash = blockAsDictionary["previousBlockHash"] as? String
//            Log(previousBlockHash)
//            let signatureForBlockAsData = signatureForBlock?.base64DecodedData
//            Log(signatureForBlockAsData)
//            let transactionsAsJsonArrayString = transactions?.dictionarysToJsonString
//            Log(transactionsAsJsonArrayString)

            if let nonceAsData = nonceAsHexadecimal.hexadecimalDecodedData,
                let blockAsDictionary = blockAsJsonString.jsonToAnyDictionary,
                let transactions = blockAsDictionary["transactions"] as? [[String : Any]],
//                let base64EncodedPublicKeyStringForTransaction = transactions.first?["publicKey"] as? String,
//                let publicKeyForTransactionAsData = base64EncodedPublicKeyStringForTransaction.base64DecodedData,
                let publicKeyForBlockAsData = base64EncodedPublicKeyStringForBlock.base64DecodedData,
//                let makerDhtAddressAsHexStringForTransaction = transactions.first?["makerDhtAddressAsHexString"] as? String,
                let signatureForBlock = blockAsDictionary["signature"] as? String,
                let id = blockAsDictionary["id"] as? String,
                let candidateNextDifficulty = blockAsDictionary["nextDifficulty"] as? String,
                let candidateNextDifficultyAsInt = Int(candidateNextDifficulty),
               let candidateDifficultyAsNonceLeadingZeroLength = blockAsDictionary["difficultyAsNonceLeadingZeroLength"] as? String,
               let candidateDifficultyAsNonceLeadingZeroLengthAsInt = Int(candidateDifficultyAsNonceLeadingZeroLength),

                let previousBlockHash = blockAsDictionary["previousBlockHash"] as? String,
                let signatureForBlockAsData = signatureForBlock.base64DecodedData,
                let transactionsAsJsonArrayString = transactions.dictionarysToJsonString {
                Log(transactions)
                Log("transactionsAsJsonArrayString: \(transactionsAsJsonArrayString)")
                Log("signatureForBlock: \(signatureForBlock)")
                LogEssential("Received Block's difficulties: \(candidateDifficultyAsNonceLeadingZeroLengthAsInt) - \(candidateNextDifficultyAsInt)")
                /*
                 どこにchainするかによって、paddingzerolength 値を変える
                 */
                let (chainable, previousBlock, nextDifficulty, branchHashString, indexInBranchChain) = (node as! Node).book.chainable(previousBlockHash: previousBlockHash, signatureForBlock: signatureForBlockAsData, node: (node as! Node))
                LogEssential("\(chainable) block id: \(id) previousBlockHash: \(previousBlockHash) nextDifficulty: \(nextDifficulty) branchHashString: \(branchHashString) indexInBranchChain: \(indexInBranchChain)")
                switch chainable {
                case .secondaryCandidateBlocksNext:
                    /*
                     Lay Secondary Candidate Block First As The Block is Secondary Candidate Block's Next
                     If Chain New Block to Secondary Candidate Block, and Remove Last Block.
                     */
                    Log("Block is Secondary Candidate Block's Next.")
//                case .storeAsSecondaryCandidateBlock:
//                    /*
//                     Chain to Second Last Block As The Block's Previous Block Hash.
//                     
//                     Function detect whether same previous block to chain the block.
//                     */
//                    Log("Store As Secondary Candidate Block.")
                case .chainableBlock:
                    /*
                     Block is To Chain Next.
                     New Block As Cached Last Block's Next.
                     */
                    Log("Block is To Chain Next.")
                case .omitBlock:
                    Log("The Block to Trash. (Omit the Block.")
                    return nil
                }
                let preBlockNonce = previousBlock.nonce
                let nonce = Nonce(paddingZeroLength: nextDifficulty, preBlockNonce: preBlockNonce, nonceAsData: nonceAsData)
                /*
                 As Chainable for lastBlock in Cached.
                 */
                if nonce.verifyNonce(preNonceAsData: preBlockNonce.asBinary) {
                    /*
                     Nonce is OK.
                     */
                    Log("Valid Nonce.")
                    guard var block = Block(maker: makerDhtAddressAsHexString, signature: signatureForBlockAsData, previousBlock: previousBlock, nonceAsData: nonceAsData, publicKey: publicKeyForBlockAsData, date: date, paddingZeroLengthForNonce: nextDifficulty, book: (node as! Node).book, id: id, chainable: chainable, previousBlockHash: branchHashString, indexInBranch: indexInBranchChain) else {
                        Log("Can NOT Construct Block.")
                        return nil
                    }
//                    let allValidTransactions = block.add(multipleMakerTransactions: transactions, node: node as! Node, chainable: chainable)
                    let allValidTransactions = block.add(multipleMakerTransactions: transactions, chainable: chainable, branchChainHash: branchHashString, indexInBranchChain: indexInBranchChain)
                    /*
                     As Protocol extension can not define settable property,
                     Do Downcast to Node.
                     
                     #now make sure find taker's transaction in chained block in Birth View.
                     */
                    (node as! Node).book.signature = signatureForBlockAsData
                    Log("-- \((node as! Node).book.blocks.count)")
                    if allValidTransactions {
                        Log("Block Have All Valid Transactions, cause Chain.")
                        (node as! Node).book.chain(block: block, chainable: chainable, previousBlock: previousBlock, node: node as! Node, branchHashString: branchHashString, indexInBranch: indexInBranchChain)
                    } else {
                        Log("Block Have Invalid Transaction, cause NOT Chain.")
                    }
                    Log("++ \((node as! Node).book.blocks.count)")
                } else {
                    Log("Invalid Nonce.")
                }
            }
            return nil
        case .publishBlockReply :
            LogEssential("Do \(self.rawValue)")
            return nil
        case .publishTransaction :   //MARK: publishTransaction
            LogEssential("Do \(self.rawValue)  From: \(fromNodeIp)")
            Log("publishTransaction")
            /*
             Transaction を受け取った
             
             （自分が Booker として振る舞うなら）←自分で決めるだけ
             ↓
             (Booker) 　←Simulatorをbookerとする
             p2pを流れてきたTransactionを validate する
             ↓
             p2pを流れてきたTransactionを New Block に追加する
             ↑いくつかの周辺nodeから同じものが送信される
             ↓
             Proof of workする
             Book標準タイミング：
                Block生成が30分に３回以内に収まるようにnonce padding難易度を設定する
             ↓
             トランザクション最大数までブロックに追加する
             #あと
             ↓
             BookしたNew Blockをp2pネットワークに流す
             近隣nodeへ送信する
             */
            
            /*
             Operands
            0: publickey base64 encoded
            1: maker dht address
            2: transaction count
            *3: transaction (Json String)
                ex. {transactionId:,date:,transaction type:,claim:,claimObject:,signature:,},{},{},...
            * Repeat Times is by transaction count.

             cf. claimObject
                [
                 "Destination": destination,
                 "PublicKeyForEncryption": publicKeyForEncryption,
                 "CombinedSealedBox": combinedSealedBox, //image binary or zip file
                 "Description": description,
                 "PersonalData": personalDataAsJsonString,
                ]
             */
            let base64EncodedPublicKeyString = operandArray[0]  //"6ZeDdzJT9f99mIvxdY0ySfgNEXK0G8Iz0LoLMCLBMlc="
            let makerDhtAddressAsHexString = operandArray[1]   //"6f7739ca1a3b1a4c5d89c74895b04cf58c10c3fbd94e4a356d6145d8f73d55ca7b4cbe84bb6f286f48e093d037c2c23d45d7667260f72a1fe01302ac4c5414c9"
            let transactionCount = operandArray[2]  //"1"

            guard let transactionCountAsInt = Int(transactionCount) else {
                Log()
                return nil
            }
            
            /*
             Store Transaction (Json contents) to Array formed string by Transaction Count.
             */
            var transactionsAsJsonArrayString = "["
            let contentStartOperandArrayIndex = 3
            for operand in operandArray[contentStartOperandArrayIndex..<operandArray.count].enumerated() {
                Log(operand.offset)//0 origin
                Log(operand.element)
                Log(operand.element) //utf8    //Base64 →Data →utf8
                let jsonString = operand.element   //if let jsonString = operand.element.base64DecodedJsonString {
                if operand.offset != 0 {    //if operand.offset != contentStartOperandArrayIndex + 1 {
                    transactionsAsJsonArrayString += ","
                }
                transactionsAsJsonArrayString += jsonString
            }
            transactionsAsJsonArrayString += "]"
            
            Log("transactionsAsJsonArrayString: \(transactionsAsJsonArrayString)")
            Log("publicKey: \(base64EncodedPublicKeyString)")

            /*
             p2pを流れてきたTransactionを validate する
             ↓
             p2pを流れてきたTransactionを New Block に追加する
             */
            /*
             前のblockからnonceを取得する
             */
            var lastBlock: Block
            if let last = (node as! Node).book.lastBlock {
                lastBlock = last
            } else {
                lastBlock = Block.genesis
            }
//            guard let publickeyForNewBlockAsData = (node as! Node).signer()?.publicKeyAsData,
//                  let publicKeyAsData = base64EncodedPublicKeyString.base64DecodedData,
//                    var block = Block(maker: node.dhtAddressAsHexString, previousBlock: lastBlock, publicKey: publickeyForNewBlockAsData, date: Date.now.toUTCString, paddingZeroLengthForNonce: (node as! Node).book.currentDifficultyAsNonceLeadingZeroLength, book: (node as! Node).book) else {
            guard let publickeyForNewBlockAsData = (node as! Node).signer()?.publicKeyAsData,
                  let publicKeyAsData = base64EncodedPublicKeyString.base64DecodedData,
//                  let paddingZeroLengthForNonce = (node as! Node).book.lastBlock?.nextDifficulty,
//                  let paddingZeroLengthForNonce = (node as! Node).book.takeNextDifficulty(for: .chainableBlock, previousBlockHash: lastBlock.hashedString, indexInBranch: ),
                    var block = Block(maker: node.dhtAddressAsHexString, previousBlock: lastBlock, publicKey: publickeyForNewBlockAsData, date: Date.now.toUTCString, book: (node as! Node).book, chainable: .chainableBlock, previousBlockHash: nil, indexInBranch: nil) else {
                return nil
            }
            let transactionsAsDictionaryArray = transactionsAsJsonArrayString.jsonToDictionaryArray
//            if block.add(singleMakerTransactions: transactionsAsDictionaryArray, makerDhtAddressAsHexString: makerDhtAddressAsHexString, publicKeyAsData: publicKeyAsData, node: node as! Node) {
            if block.add(singleMakerTransactions: transactionsAsDictionaryArray, makerDhtAddressAsHexString: makerDhtAddressAsHexString, publicKeyAsData: publicKeyAsData, branchChainHash: nil, indexInBranchChain: nil) {
            } else {
                return nil
            }

            /*
             Transactionの最大数を決める（1 Block内）
             ↑
             max 30 transactions / block ぐらい？
             #pending
             */
            Log()
            if let signer = (node as! Node).signer() {
                /*
                 add new block to own node's book.
                 */
                LogEssential("Make Chain Own Generated Block to Own Node's Book.")
                block.chain(previousBlock: lastBlock, node: node, signer: signer)

                /*
                 BookしたNew Blockをp2pネットワークに流す
                 近隣nodeへ送信する
                 */
                Log("Publish Block to known Nodes.")
                Log((node as! Node).signer()?.privateKeyForSignature?.rawRepresentation.base64String)
                Log((node as! Node).signer()?.privateKeyForSignature?.rawRepresentation.base64String)
                block.send(node: node, signer: signer)
            }
            return nil
        case .publishTransactionReply :
            LogEssential("Do \(self.rawValue)")
            /*
             Operands
             
             0: hashed key
             1: responsible node finger address
             */
            
            /*
             operands[0]のresultが空なら
             operands[1]のipアドレスに再度FRコマンドを送る
             resultがあれば
             リソース取得完了となる
             */
            let key = operandArray[0]
            let responsibleNodeAddress = operandArray[1]
            if responsibleNodeAddress != "" {
                /*
                 Taker 取得完了
                 */
                Log("Have Got Taker: \(responsibleNodeAddress)")
            } else if let responsibleNode = Node(dhtAddressAsHexString: responsibleNodeAddress) {
                /*
                 ex.
                 ・Taker取得の流れ
                 A Node as Seeking Taker）
                 Takerを探したい
                 ↓
                 Transactionを作って（Mail）
                 自分のdhtアドレス
                 宛先dhtアドレス(baby sitter node)
                 要求（Find Taker Node)
                 手数料額　単位BK（標準は 1BK)
                 署名（秘密鍵で）
                 ↓
                 Transactionを known node にブロードキャストする（Mail）
                 自分が知っているnodeに対して block を送信する
                 known node:
                 predecessor, successor, babysitter(arbitrary node)
                 or
                 all entry node in finger table
                 ↓
                 (Booker)
                 p2pを流れてきたTransactionを validate する
                 ↓
                 p2pを流れてきたTransactionを New Block に追加する
                 ↑いくつかの周辺nodeから同じものが送信される
                 ↓
                 Proof of workする
                 Bookタイミング：５分ごと
                 問題）具体例
                 #pending
                 ↓
                 BookしたNew Blockをp2pネットワークに流す
                 近隣nodeへ送信する
                 ↓
                 一番早く解けたら正規のBlock chainとなる
                 一番早くの決め方について
                 ↑3つNew BlockがAddされて、結果、多数のBookerが採用した Book が
                 一番早かったとなる
                 ↓
                 一番早いBookerに1BKが支払われる
                 ↓
                 Taker)
                 p2pを流れてきたTransactionを validate する
                 ↓
                 Takerとして振る舞うが有効なら　（Settingで切り替え）
                 自分の in charge of 責任範囲かチェックする
                 ↓
                 アプリ画面に通知（責任範囲 or 自分宛のMail）を表示
                 ↓
                 Transactionを作って（Mail）
                 自分のdhtアドレス（Taker)
                 宛先dhtアドレス(seeking taker)
                 要求（Find Taker Node)
                 結果（Taker dht address, Taker public key）
                 手数料額　単位BK（標準は 1BK)
                 署名（秘密鍵で）
                 ↓
                 （以下上記Bookerと同じ流れでBookされる）
                 ↓
                 A Node as Seeking Taker）
                 近隣nodeから受信したブロックのTransactionを見る
                 ↓
                 アプリ画面に通知を表示する
                 Takerとしてアプリに記憶する
                 */
                
            }
            return nil
            
            /*
             Fetch Resources
             
             #pending
             */
//        case .fetchResource :   //MARK: fetchResource
//            //See over finger table, then Confirm be in charged of the resource.
//            /*
//             0: Hashed Key
//
//             if in charged of it,
//             return resource
//
//             if other node's responsible,
//             return node's ip address
//             */
//            let key = operandArray[0]
//            if key == "" {
//                Log()
//                return nil
//            }
//            if let (resourceString, responsibleNodeIpAndPort) = node.fetchResource(hashedKey: key) {
//                /*
//                 0: result (resource as String)
//                 1: responsible node ip
//                 */
//                return operandUnification(operands: [key, resourceString, responsibleNodeIpAndPort])
//            }
//            return nil
//        case .fetchResourceReply :
//            /*
//             Operands
//
//             0: hashed key
//             1: result (resource as String)
//             2: responsible node ip
//             */
//
//            /*
//             operands[0]のresultが空なら
//             operands[1]のipアドレスに再度FRコマンドを送る
//             resultがあれば
//             リソース取得完了となる
//             */
//            let key = operandArray[0]
//            let resultString = operandArray[1]
//            let responsibleNodeIpAndPort = operandArray[2]
//            if resultString != "" {
//                /*
//                 リソース取得完了
//                 */
//                Log("Have Fetched Resource: \(resultString)")
//            } else if let ipAndNode = Node(ipAndPort: responsibleNodeIpAndPort) {
//                //Send FR Command to retry.
//                Command.fetchResource.send(node: node, to: ipAndNode.getIp, operands: [key]) { string in
//                    Log(string)
//                }
//            }
//            return nil
        default:
            Log()
            return ""
        }
    }
}