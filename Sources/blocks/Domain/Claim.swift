//
//  Claim.swift
//  Testy
//
//  Created by よういち on 2023/09/10.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

/*
 Claim by Transaction
 */
import Foundation
import overlayNetwork

public protocol Claim {
    associatedtype ClaimType
    
    init?(rawValue: String)
    var rawValue: String? { get }
    var rawValueWithAbstract: String? { get }
    func object(content: String) -> ClaimObject?

    var replyClaim: String { get }
    var sendClaim: String { get }
    func isReply() -> Bool
    static func rawValue(_ claim: ClaimType) -> String
    static var null: ClaimType? { get }
    func replyBody(destinationDhtAddress: OverlayNetworkAddressAsHexString, description: String, signer: Signer, combinedSealedBox: Data?, attachedFileType: FileType?, personalDataAsEncrypted: Data?) -> [String: String]?
    static var destinationBroadCast: String { get }
}

public protocol ClaimObject {
    func toDictionary(signer: Signer?, peerSigner: Signer?) -> [String: String]?
    func toJsonString(signer: Signer?, peerSigner: Signer?) -> String?
}

public extension Claim {
    static var destinationBroadCast: String {
        "BroadCast"
    }
}
