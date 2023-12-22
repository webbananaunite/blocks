//
//  Decimal+.swift
//  blocks
//
//  Created by よういち on 2023/11/06.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation

extension Decimal {
    static let neededDigits = 38    //Decimal.decimalMaxValue 99999999999999999999999999999999999999
    static var decimalMaxValue: Decimal {
        Decimal(string: String(repeating: "9", count: Decimal.neededDigits))!    //Decimalの最大値（10進数 38桁）
    }
    
    /*
     Decimalの小数点以下を切り捨てる
     */
    func truncateAfterDecimalPoint() -> Decimal {
        let preTruncatedValue = UnsafeMutablePointer<Decimal>.allocate(capacity: 1)
        preTruncatedValue[0] = self
        Log(preTruncatedValue.pointee)
        let preTruncatedValuePointer = UnsafePointer<Decimal>(preTruncatedValue)
        NSDecimalRound(preTruncatedValue, preTruncatedValuePointer, 0, .down)
        Log("raw value: \(self)")
        Log("processed value: \(preTruncatedValue.pointee)")
        return preTruncatedValue.pointee
    }

    func quotientAndRemainder(_ modulo: Decimal) -> (Decimal, Decimal) {
        guard self <= Decimal.decimalMaxValue else {
            return (Decimal.zero, Decimal.zero)
        }
        let quotientVal = self / modulo
        //Decimalの小数点以下を切り捨てる
        let truncatedAfterDecimalPoint = quotientVal.truncateAfterDecimalPoint()
        let remainderVal = self - truncatedAfterDecimalPoint * modulo
        
        Log(modulo)
        Log(self)
        Log(remainderVal)
        return (truncatedAfterDecimalPoint, remainderVal)
    }
    
    //小数点以下桁数が範囲内かチェックする
    func validDigitsOfFraction(_ validDigitsOfFraction: Int) -> Bool {
        let integerValue = self.truncateAfterDecimalPoint()
        let decimalValue = self - integerValue
        let decimalAsString = decimalValue.formatted()
        let integerAndFractions = decimalAsString.components(separatedBy: ".")
        Log(integerAndFractions.count)
        Log(validDigitsOfFraction)
        if integerAndFractions.count == 1 {
            Log("Valid Integer value")
            return true
        }
        guard integerAndFractions.count == 2, integerAndFractions[1].count <= validDigitsOfFraction else {
            Log("Invalid - Fraction Digits is over.")
            return false
        }
        Log("Valid Decimal value")
        return true
    }

}
