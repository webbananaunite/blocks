//
//  NonceTest.swift
//  TestyTests
//
//  Created by よういち on 2023/09/18.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import XCTest
@testable import blocks

final class NonceTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testNonce() throws {
        #if false
        //ok
        let nonce = Nonce(paddingZeroLength: 4, preBlockNonce: Block.genesis.nonce) //1秒未満　nil 候補 + 2^2     前版：nil 候補 + 2^36     30回ぐらい
//        if let expectedResultAsData = "0000000010".data(using: .hexadecimal) {
        if let expectedResultAsData = "04".data(using: .hexadecimal) {
            Dump(expectedResultAsData)
            XCTAssertEqual(nonce.asBinary, expectedResultAsData)
        }
        #endif
        //ok
        #if false
        let nonce = Nonce(paddingZeroLength: 8, preBlockNonce: Block.genesis.nonce) //1.7秒　Optional(0) 候補 + 2^390      前版：135回
        if let expectedResultAsData = "01000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040".data(using: .hexadecimal) {
            Dump(expectedResultAsData)
            XCTAssertEqual(nonce.asBinary, expectedResultAsData)
        }
        #endif
//        let nonce = Nonce(paddingZeroLength: 18) //前版：見つからない 3100回でも Log()を全て削除して実行した
        //ok
        #if true
        let nonce = Nonce(paddingZeroLength: 16, preBlockNonce: Block.genesis.nonce)    //98秒　Optional(103) 候補 + 2^460       前版：19秒　Optional(18) 候補 + 2^239　simulatorだと31秒かかった
        if let expectedResultAsData = "ffffffffffffffffffffffffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010".data(using: .hexadecimal) {
            Dump(expectedResultAsData)
            XCTAssertEqual(nonce.asBinary, expectedResultAsData)
        }
        #endif
//        let nonce = Nonce(paddingZeroLength: 17)    //前版：見つからない　１時間以上たっても　GPU計算が必要？

        //ok
        #if false
        /*
         Hash preNonce + nonce as Hexadecimal
         000007dd a770835d 2e580215 0960cb4c 9f440cc1 86890b9e e823dd5d 8e54cccb 3cbd543d 1d471d4b 0b32e095 28781de9 50f65daf c222999f e00cbf20 e9d1d408
         
         Nonce Value As represent Little Endian
         ffffffff ffffffff ffffffff ffffffff ffffffff ffffffff ffff7f00 00000000 00000000 00000000 00000000 00000000 00000000 000001
         */
//        let nonce = Nonce(paddingZeroLength: 20, preBlockNonce: Block.genesis.nonce)    //203秒　Optional(214) 候補 + 2^432
        let nonce = Nonce(paddingZeroLength: 19, preBlockNonce: Block.genesis.nonce)    //218秒　Optional(214) 候補 + 2^432
        if let expectedResultAsData = "ffffffffffffffffffffffffffffffffffffffffffffffffffff7f00000000000000000000000000000000000000000000000000000001".data(using: .hexadecimal) {
            Dump(expectedResultAsData)
            XCTAssertEqual(nonce.asBinary, expectedResultAsData)
        }
        #endif

        let verified = nonce.verifyNonce(preNonceAsData: Block.genesis.nonce.asBinary)
        Log(verified)
        XCTAssertEqual(verified, true)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
