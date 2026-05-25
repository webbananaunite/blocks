//
//  ClaimObjectContent.swift
//  blocks
//
//  Created by Codex on 2026/05/24.
//

import Foundation
import overlayNetwork

enum ClaimObjectContent {
    static func commonFields(from content: String) -> (destination: OverlayNetworkAddressAsHexString, publicKeyForEncryption: PublicKeyForEncryption?, combinedSealedBox: String, description: String, attachedFileType: String)? {
        guard let dictionary = content.jsonToAnyDictionary else {
            return nil
        }

        let publicKeyForEncryptionString = stringValue(for: "PublicKeyForEncryption", in: dictionary)
        let publicKeyForEncryption = publicKeyForEncryptionString.isEmpty ? nil : publicKeyForEncryptionString.base64DecodedData

        return (
            destination: stringValue(for: "Destination", in: dictionary),
            publicKeyForEncryption: publicKeyForEncryption,
            combinedSealedBox: stringValue(for: "CombinedSealedBox", in: dictionary),
            description: stringValue(for: "Description", in: dictionary),
            attachedFileType: stringValue(for: "AttachedFileType", in: dictionary, fallbackKey: "attachedFileType")
        )
    }

    private static func stringValue(for key: String, in dictionary: [String: Any], fallbackKey: String? = nil) -> String {
        if let value = dictionary[key] as? String {
            return value
        }
        if let fallbackKey, let value = dictionary[fallbackKey] as? String {
            return value
        }
        return ""
    }
}
