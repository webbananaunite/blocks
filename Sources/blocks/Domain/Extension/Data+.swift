//
//  Data+.swift
//  blocks
//
//  Created by よういち on 2023/09/19.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation

extension Data {
    /*
     Data as [UInt8]'s Exclusive OR as Compute Nonce Difficulty
     
     lhs: computed data
     rhs: leading padding zero mask as difficulty (mask is 0)
     */
    static func ^ (lhs: Data, rhs: Data) -> Bool {
        var foundNonce = false
        for index in 0..<Int(Nonce.bytes) {  //..<64
            if lhs[index] ^ rhs[index] <= rhs[index] {
//                Log("Match")
                foundNonce = true
            } else {
//                Log("Un Match")
                foundNonce = false
                break
            }
        }
        return foundNonce
    }
    
    /*
     Thank:
     https://stackoverflow.com/a/45813345
     
     Data to [bytes]
     */
    var toUint8Array: [UInt8] {
        return [UInt8](self)
    }
    
}
