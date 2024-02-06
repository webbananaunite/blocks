//
//  Difficulty.swift
//  blocks
//
//  Created by よういち on 2023/12/20.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation

public protocol Difficulty {
    static var minDifficulty: Difficulty {
        get
    }
    static var maxDifficulty: Difficulty {
        get
    }
    static var difficultyDefaultValue: Difficulty {
        get
    }
    func validDifficulty() -> Bool
    var toInt: Int {
        get
    }
    func equal(_ value: Difficulty) -> Bool
}

extension Int: Difficulty {
    /*
     Leading Zero Length in Nonce Value.
     
     Value Range is 16 - 512 (<= Nonce.hashedBits)
     */
    public static var minDifficulty: Difficulty = 16
    public static var maxDifficulty: Difficulty = 512
    public static var difficultyDefaultValue: Difficulty = Nonce.defaultZeroLength
    public func validDifficulty() -> Bool {
        self.toInt <= Self.maxDifficulty.toInt && self.toInt >= Self.minDifficulty.toInt
    }
    public var toInt: Int {
        self
    }
    public func equal(_ value: Difficulty) -> Bool {
        self.toInt == value.toInt
    }
}
