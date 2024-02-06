//
//  Nonce.swift
//  blocks
//
//  Created by よういち on 2023/09/18.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation
import Metal

/*
 Nonce Value is variable length Binary represented Little Endian.
 */
public class Nonce {
    public var asBinary: Data = Data.DataNull       //[UInt8]
    var asHex: String {      //binary As Hexa decimal String
        self.asBinary.hex()
    }
    public var compressedHexaDecimalString: String {
        Log()
        /*
         重複文字は個数を渡すようにする
         cf. f{19}0{2}a1
         */
        let compressedNonceAsString = self.asBinary.compressedString
        Log(compressedNonceAsString)
        return compressedNonceAsString
    }
    public func deCompressedData(compressedHexString: String) -> Data? {
        return compressedHexString.decomressedData
    }

    let nonceMaxBitLength = 1048576
//    static let bits: UInt = 512
//    static let bytes: UInt = 64
//    static let hexStringLength = 128
    static let hashedBits: UInt = 512
    static let hashedBytes: UInt = 64

    /*
     Difficulty as Proof of Work
     */
    static let minimumSecondsInProofOfWorks: TimeInterval = 20 * 60  //As Seconds
    public static let defaultZeroLength: Difficulty = 16
    /*
     Value Range is 0 - 512 (Nonce.hashedBits)
     Default value is 16
     */
    let leadingZeroLength: Difficulty
    
    /*
     Book標準タイミング：
     Block生成が30分に1回以内に収まるように nonce padding difficulty難易度 を設定する
     */

    //Use as restore secondary candidate block.
    public init(paddingZeroLength: Difficulty = Nonce.defaultZeroLength, nonceAsData: Data) {
        Log()
        self.leadingZeroLength = paddingZeroLength
        self.difficultyAsUseExclusiveOR = makeDifficultyAsUseExclusiveOR()
        self.asBinary = nonceAsData
    }
    
    public init(paddingZeroLength: Difficulty = Nonce.defaultZeroLength, preBlockNonce: Nonce, nonceAsData: Data? = nil) {
        Log()
        self.leadingZeroLength = paddingZeroLength
        self.difficultyAsUseExclusiveOR = makeDifficultyAsUseExclusiveOR()
        if let nonceAsData = nonceAsData {
            self.asBinary = nonceAsData
        } else {
            self.asBinary = makeNonce(preBlockNonce: preBlockNonce)
        }
    }

    public init(genesis paddingZeroLength: Int = Nonce.genesisBlockDifficulty) {
        self.leadingZeroLength = paddingZeroLength
        self.difficultyAsUseExclusiveOR = Data(repeating: 0xff, count: 64)
        self.asBinary = Data(repeating: UInt8.zero, count: 64)
    }
    public static var genesisBlockNonce = Nonce(genesis: 0)
    public static var genesisBlockDifficulty = 512  //Max Difficulty Value

    /*
     0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
     max: 512 bits
     hex: 128 chars
     */
    var difficultyAsUseExclusiveOR: Data = Data.DataNull
    private func makeDifficultyAsUseExclusiveOR() -> Data {
        var difficultyAsExclusiveOR = Data(repeating: 0xff, count: Int(Nonce.hashedBytes))
//        Dump(difficultyAsExclusiveOR)
        for number in 0..<self.leadingZeroLength.toInt {
            let index = number / UInt8.bitWidth
            let exp = number - (index * UInt8.bitWidth)
            /*
             XOR
             
             1111 1111 ^ 1000 0000
             ↓
             0111 1111
             */
//            Log(difficultyAsExclusiveOR[index])
            difficultyAsExclusiveOR[index] ^= (0x01 << (UInt8.bitWidth - 1 - exp))
//            Log(difficultyAsExclusiveOR[index])
        }
//        Dump(difficultyAsExclusiveOR)
        return difficultyAsExclusiveOR
    }
    
    public func verifyNonce(preNonceAsData: Data) -> Bool {
        Dump(self.asBinary)
        let hashedComputedData = (preNonceAsData + self.asBinary).hash
        Dump(hashedComputedData)
        Dump(difficultyAsUseExclusiveOR)
        let foundNonce = hashedComputedData ^ difficultyAsUseExclusiveOR
        Log(foundNonce)
        return foundNonce
    }
    
    #if UseGPU
    /*
     GPU Powered Calculate Nonce.
     */
    let gpuParallelProcedureLength = 1048576
    private func makeNonce(preBlockNonce: Nonce) -> Data {
        Log()
        var candidateNonceValue: Data = Data.DataNull
        var addingExponent: UInt = 0
        var fixExponents: UInt? = nil
        var foundNonce: Bool = false
        
        /*
         計算される値を設置する
         */
        for _ in 0..<yCount*xCount {
            candidateNonceValue.append(Data.DataNull)
        }
        
        initMetal()
        let matchedNonce = startGPU(preBlockNonce: preBlockNonce)
        return matchedNonce
    }
    #else
    /*
     CPU Powered Calculate Nonce
     */
    private func makeNonce(preBlockNonce: Nonce) -> Data {
        LogEssential("###Started Make Nonce Approach.")
        var candidateNonceValue: Data = Data.DataNull
        var addingExponent: UInt = 0
        var fixExponents: UInt? = nil
        var foundNonce: Bool = false
        for a: Int in -1..<nonceMaxBitLength {
            fixExponents = a >= 0 ? UInt(a) : nil
            makeNonce(addingExponent: &addingExponent, candidateNonceValue: &candidateNonceValue, fixExponent: &fixExponents, foundNonce: &foundNonce, preNonceAsData: preBlockNonce.asBinary)
            Dump(candidateNonceValue)
            if foundNonce {
                break
            } else {
                //次へ
                Log("Nonce候補をインクリメントし次へ")
                var fixexp: UInt = 0
                if let value = fixExponents {
                    fixexp = value + 1
                }
                candidateNonceValue = candidateNonceValue.add(exponent: fixexp)
                fixExponents = fixexp
                addingExponent = fixexp + 1
            }
        }
        LogEssential("###Finished Make Nonce Approach.")
        LogEssential(addingExponent)
//        LogEssential(candidateNonceValue.compressedString)
        return candidateNonceValue
    }
    #endif

    /*
     Compute Nonce as Metal Code for async GPU Computing.
     
     Thank:
     https://hirauchi-genta.com/swift-metal-gpgpu/
     */
    //MTLDevice生成
    private let device = MTLCreateSystemDefaultDevice()
    private var library: MTLLibrary?
    private var commandQueue: MTLCommandQueue?
    private var computePipelineState: MTLComputePipelineState?
    
    private let yCount = 1000
    private let xCount = 1000
    private var candidateNonceValue: [UInt8] = []

    // Metal初期化
    private func initMetal() {
        //MTLLibrary生成
        guard let device = device else {
            fatalError("device is nil.")
        }
        Log()
        let frameworkBundle = Bundle(for: blocks.Nonce.self)
        guard let defaultLibrary = try? device.makeDefaultLibrary(bundle: frameworkBundle) else {
            fatalError("Could not load default library from specified bundle")
        }
        library = defaultLibrary
        guard let library = library else {
            fatalError("library is nil.")
        }

        Log()
        //MTLFunction生成
        guard let function = library.makeFunction(name: "testFunction") else {
            fatalError("make function error occurred.")
        }
        //MTLComputePipelineState生成
        do {
            computePipelineState = try device.makeComputePipelineState(function: function)
        } catch {
            fatalError("error: \(error)")
        }
        Log(computePipelineState)
        //MTLCommandQueue生成
        commandQueue = device.makeCommandQueue()
        Log(commandQueue)
    }
    #if UseGPU
    /*
     GPU Powered Calculate Nonce.
     
     GPUへ渡す引数をセットして 実行 waitUntilCompleted する
     （GPU引数：並列実行数 GPU Parallel Procedure の長さ分）
     */
    private func startGPU(preBlockNonce: Nonce) -> Data {
        /*
         Define Shader Parameters
    
         var {Parameter} = [{Parameter Type}]()  //Array Length is {gpuParallelProcedureLength}
         */
        var candidateNonceArray = [[UInt8]]()   //[2^8]     ←Radix 256
        var candidateNonce = [UInt8]()   //[2^8]     ←Radix 256
        var candidateNonceLength = [Int]()
        var addingExponent = [UInt]()
        var fixExponents = [Int]()  // nil: -1
        var foundNonce = [Bool]()
        
        //Temporary Variable
        var addingExponentValue = UInt(0)
        var candidateNonceValue: [UInt8] = [UInt8.zero]
        
        /*
         gpuParallelProcedureLength 個のgpuで並列実行するための値群をセットする
         
            varName[nonceMaxBitLength]
         */
        var amountNonceBufferLength = 0
        for placedExponent: Int in -1..<self.gpuParallelProcedureLength {
            var fixExponentsValue = placedExponent >= 0 ? Int(placedExponent) : Int(-1)
            if addingExponentValue < Nonce.hashedBits {
                addingExponentValue += 1
            } else {
                //次へ
                Log("Nonce候補をインクリメントし次へ")
                var fixexp: Int = 0
                fixexp = Int(fixExponentsValue + 1)
                let addedNonceValue = candidateNonceValue.toData.add(exponent: UInt(fixexp)).toUint8Array
                //上位桁（[]配列の大きい添字の方に）毎回512 bit padding追加する
                candidateNonceValue = addedNonceValue.regularPaddingHigh(bytes: Nonce.hashedBytes, compare: candidateNonceValue)
                
                /*
                 ↑
                 placedExponent: candidateNonceValue
                 -1: nil + 2^512(512 bit)
                 0: 2^0 + 2^512
                 1: 2^1 + 2^512
                 2: 2^2 + 2^512
                 */
                fixExponentsValue = fixexp
                addingExponentValue = UInt(fixexp + 1)
            }
            candidateNonceArray.append(candidateNonceValue)
            candidateNonceLength.append(candidateNonceValue.count)
            amountNonceBufferLength += candidateNonceValue.count
            addingExponent.append(addingExponentValue)
            fixExponents.append(fixExponentsValue)
            foundNonce.append(false)
        }
        
        candidateNonce = candidateNonceArray.flatMap {
            $0
        }
        
        let start = Date().timeIntervalSince1970
        
        //MTLBuffer
        //入出力バッファ生成
        guard let device = device else {
            fatalError("device is nil.")
        }
        let bufferLength = self.gpuParallelProcedureLength + 1  //Cause Range is -1...gpuParallelProcedureLength
        let addingExponentBuffer = device.makeBuffer(bytes: addingExponent, length: MemoryLayout<UInt>.stride * bufferLength, options: [])//[UInt]
        let candidateNonceBuffer = device.makeBuffer(bytes: candidateNonce, length: MemoryLayout<UInt8>.stride * amountNonceBufferLength, options: [])//: [[UInt8]]
        let candidateNonceLengthBuffer = device.makeBuffer(bytes: candidateNonceLength, length: MemoryLayout<Int>.stride * bufferLength, options: [])//: [Int]

        let fixExponentsBuffer = device.makeBuffer(bytes: fixExponents, length: MemoryLayout<UInt>.stride * bufferLength, options: [])//: [Int]
        let foundNonceBuffer = device.makeBuffer(bytes: foundNonce, length: MemoryLayout<Bool>.stride * bufferLength, options: [])//: Bool
        let preNonceAsDataBuffer = device.makeBuffer(bytes: preBlockNonce.asBinary.toUint8Array, length: MemoryLayout<UInt8>.stride * preBlockNonce.asBinary.toUint8Array.count, options: [])//:

        //MTLCommandBuffer生成
        /*
         Grids
         ↓
         Thread Groups
         ↓
         Threads
         ↓
         Command Env
         ↓
         Device
         ↓              ↓
         Buffer         Pipeline
                        ↓
                        Library
                        ↓
                        Function
         ↓
         commit()で並列実行
        */
        guard let commandQueue = commandQueue else {
            fatalError("commandQueue is nil.")
        }
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            Log()
            //MTLComputeCommandEncoder生成
            if let computeCommandEncoder = commandBuffer.makeComputeCommandEncoder() {
                Log()
                guard let computePipelineState = computePipelineState else {
                    fatalError("computePipelineState is nil.")
                }
                computeCommandEncoder.setComputePipelineState(computePipelineState)
                /*
                 Shader関数に渡す引数　6つ
                 */
                computeCommandEncoder.setBuffer(addingExponentBuffer, offset: 0, index: 0)  //Data
                computeCommandEncoder.setBuffer(candidateNonceBuffer, offset: 0, index: 1)  //Data
                computeCommandEncoder.setBuffer(candidateNonceLengthBuffer, offset: 0, index: 2)  //Int
                computeCommandEncoder.setBuffer(fixExponentsBuffer, offset: 0, index: 3)  //
                computeCommandEncoder.setBuffer(foundNonceBuffer, offset: 0, index: 4)  //
                computeCommandEncoder.setBuffer(preNonceAsDataBuffer, offset: 0, index: 5)  //

                //スレッドグループ数、スレッド数設定
                let width = computePipelineState.threadExecutionWidth
                let threadgroupsPerGrid = MTLSize(width: (candidateNonceValue.count + width - 1) / width, height: 1, depth: 1)
                let threadsPerThreadgroup = MTLSize(width: width, height: 1, depth: 1)
                computeCommandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
                
                //エンコード終了
                computeCommandEncoder.endEncoding()
            } else {
                Log()
            }
            
            //コマンドバッファ実行
            /*
             //完了ハンドラーを使うとき
             commandBuffer.addCompletedHandler {commandBuffer in
                     let data = NSData(bytes: outVectorBuffer.contents(), length: sizeof(NSInteger))
                     var out: NSInteger = 0
                     data.getBytes(&out, length: sizeof(NSInteger))
                     print("data: \(out)")
                 }
             */
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        } else {
            Log()
        }
        
        //結果取得
        let candidateNonceValueResultData = Data(bytesNoCopy: candidateNonceBuffer!.contents(), count: MemoryLayout<UInt8>.stride * amountNonceBufferLength, deallocator: .none)
        let candidateNonceLengthData = Data(bytesNoCopy: candidateNonceLengthBuffer!.contents(), count: MemoryLayout<UInt8>.stride * bufferLength, deallocator: .none)
        let fixExponentResultData = Data(bytesNoCopy: fixExponentsBuffer!.contents(), count: MemoryLayout<UInt>.stride * bufferLength, deallocator: .none)
        let foundNonceResultData = Data(bytesNoCopy: foundNonceBuffer!.contents(), count: MemoryLayout<Bool>.stride * bufferLength, deallocator: .none)
        
        candidateNonce = candidateNonceValueResultData.withUnsafeBytes { Array(UnsafeBufferPointer(start: $0.baseAddress!.assumingMemoryBound(to: UInt8.self), count: $0.count / MemoryLayout<UInt8>.size)) }
        candidateNonceLength = candidateNonceLengthData.withUnsafeBytes { Array(UnsafeBufferPointer(start: $0.baseAddress!.assumingMemoryBound(to: Int.self), count: $0.count / MemoryLayout<Int>.size)) }
        fixExponents = fixExponentResultData.withUnsafeBytes { Array(UnsafeBufferPointer(start: $0.baseAddress!.assumingMemoryBound(to: Int.self), count: $0.count / MemoryLayout<Int>.size)) }
        foundNonce = foundNonceResultData.withUnsafeBytes { Array(UnsafeBufferPointer(start: $0.baseAddress!.assumingMemoryBound(to: Bool.self), count: $0.count / MemoryLayout<Bool>.size)) }
        
        var matchedIndex: Int?
        for founded in foundNonce.enumerated() {
            if founded.element {
                matchedIndex = founded.offset
                break
            }
        }
        
        let end = Date().timeIntervalSince1970
        print("GPU || candidateNonceValue.first: \(candidateNonceValue.first), candidateNonceValue.last: \(candidateNonceValue.last), time: " + String(format: "%.5f ms", (end - start) * 1000))

        var targetStartIndex = 0
        var targetEndIndex = 0
        if let matchedIndex = matchedIndex {
            for index in 0..<matchedIndex {
                targetStartIndex += candidateNonceLength[index]
            }
            targetEndIndex = candidateNonceLength[matchedIndex]
            let matchedNonce: [UInt8] = [UInt8](candidateNonce[targetStartIndex...targetEndIndex])
            return matchedNonce.toData
        }
        return Data.DataNull
    }
    #else
    
    /*
     CPU Powered Calculate Nonce.
     
     Should be #rewrite Metal code as async and GPU calculation for calculate faster.
     */
    private func makeNonce(addingExponent: inout UInt, candidateNonceValue: inout Data, fixExponent: inout UInt?, foundNonce: inout Bool, preNonceAsData: Data) {
//        LogEssential("\(String(describing: fixExponent)) 候補目")
//        Dump(candidateNonceValue)
//        LogEssential("+ 2^\(addingExponent)")
        let addedValue = candidateNonceValue.add(exponent: addingExponent)  //Nonce value is as Little Endian
//        Dump(addedValue)
        let hashedComputedData = (preNonceAsData + addedValue).hash

//        Log("Hashed.")
//        Dump(hashedComputedData)  //7b54b668 36c1fbdd 13d2441d 9e1434dc 62ca677f b68f5fe6 6a464baa decdbd00 576f8d6b 5ac3bcc8 0844b7d5 0b1cc660 3444bbe7 cfcf8fc0 aa1ee3c6 36d9e339
        let found = hashedComputedData ^ difficultyAsUseExclusiveOR
        if found {
            Log("Nonce発見")
//            Log("\(String(describing: fixExponent)) 候補 + 2^\(addingExponent)")
            Log("Have Computed Nonce.")
            candidateNonceValue = addedValue
//            Dump(candidateNonceValue)
//            Dump(hashedComputedData)
            foundNonce = found
        } else {
            if addingExponent < Nonce.hashedBits {
                addingExponent += 1
//                Log("次の桁へ + 2^\(addingExponent)")
                makeNonce(addingExponent: &addingExponent, candidateNonceValue: &candidateNonceValue, fixExponent: &fixExponent, foundNonce: &foundNonce, preNonceAsData: preNonceAsData)
            } else {
                /*
                 move to 'for in' loop
                 */
            }
        }
    }
    #endif
}
