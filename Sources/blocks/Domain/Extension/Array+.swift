//
//  Array+.swift
//  blocks
//
//  Created by よういち on 2023/09/29.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation

extension Array where Element == UInt8 {
    /*
     Thank:
     https://stackoverflow.com/a/45813345
     
     [bytes] to Data
     */
    var toData: Data {
        return Data(self)
    }
    
    func regularPaddingHigh(bytes: UInt, compare: [Element]) -> [Element] {
        let expandedBytes = Int(bytes) - (self.count - compare.count)
        guard expandedBytes > 0 else {
            return self
        }
        return self + Array(repeating: UInt8.zero, count: expandedBytes)
    }
    
}
