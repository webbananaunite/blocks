//
//  QuadKeyTest.swift
//  TestyTests
//
//  Created by よういち on 2023/08/02.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import XCTest
@testable import blocks

final class QuadKeyTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testMakeQuadKeyString() throws {
        /*
         lat long
         ↓
         Pixel xy
         ↓
         Tile xy
         ↓
         QuadKey string
         
         緯度が35.716701、経度が139.759556

         確認
         https://tools.9revolution9.com/ja/geo/geocode/
         */
        let latitude: Double = 36.292
        let longitude: Double = 120.325
        //13210301120102020133
//        let latitude: Double = 35.716701
//        let longitude: Double = 139.759556
//        //↑quadkey: 13300211231002302131
        
//        let level = 12
        let level = 20  //←これが文字数となる

        var pixelX: Int = 0
        var pixelY: Int = 0
        var tileX: Int = 0
        var tileY: Int = 0
        QuadKey.LatLongToPixelXY(latitude: latitude, longitude: longitude, levelOfDetail: level, pixelX: &pixelX, pixelY: &pixelY)
        
        QuadKey.PixelXYToTileXY(pixelX: pixelX, pixelY: pixelY, tileX: &tileX, tileY: &tileY)
        
        let quadKeyString = QuadKey.TileXYToQuadKey(tileX: tileX, tileY: tileY, levelOfDetail: level)
        Log(quadKeyString)  //{level}文字数
        XCTAssertEqual(quadKeyString, "13210301120102020133")
//        XCTAssertEqual(quadKeyString, "13300211231002302131")
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
