//
//  Work.swift
//  blocks
//
//  Created by よういち on 2023/10/18.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation

public enum Work {
    case birthCertificate       //出生届(出生証明書）
    case basicincomeAtBorn
    case basicincomeMonthly
    
    public func income() -> Decimal {
        switch self {
        case .birthCertificate:
            return 100
        case .basicincomeAtBorn:
            return 70000
        case .basicincomeMonthly:
            return 70000
        }
    }
}
