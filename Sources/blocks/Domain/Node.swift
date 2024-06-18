//
//  Node.swift
//  blocks
//
//  Created by よういち on 2023/08/16.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation
import overlayNetwork

public extension overlayNetwork.NodeProtocol {
    /*
     Caution:
     
     if wanna access function which define in protocol extension,
        down cast to implementation class.
     */
}

open class Node: overlayNetwork.Node {
    public var book: Book = Book(signature: Data.DataNull) {
        didSet {
            Log("fired didSet book")
            book.recordLibrary()
        }
    }
    private var _signer: Signer? = nil {
        didSet {
            Log("fired didSet _signer")
            _signer?.recordLibrary()
        }
    }
    /*
     As Access function signer() on Class Implementation,
        Do Down cast to 'Node'.
     
        ex.
        let signer = (node as! Node).signer().
     */
    public func signer() -> Signer? {
        Log()
        if let _ = _signer {
        } else {
            _signer = Signer(newPrivateKeyOn: self.dhtAddressAsHexString)
        }
        return _signer
    }
    public func setSigner(signer: Signer) {
        Log()
        _signer = signer
    }
    /*
     Make Signer Instance without Store Property and Record Library.
     */
    public func silentSigner() -> Signer? {
        Log()
        let silentSigner: Signer?
        if let signer = _signer {
            silentSigner = signer
        } else {
            silentSigner = Signer(newPrivateKeyOn: self.dhtAddressAsHexString)
        }
        return silentSigner
    }
    
    /*
     App enter background, to save storage.
     
     Change property, to save storage.
     Boot App, to restore.
     
     to store property:
        book.difficultyAsNonceLeadingZeroLength (=paddingZeroLength)
        signer().SignatureKeyPair
        signer().EncryptionKeyPair
        signer().makerDhtAddressAsHexString
     */
    public func recordLibrary() {
        Log("Storage the Node Properties DHTAddress, KeyPairs and Difficulty.")
        self.signer()?.recordLibrary()
        self.book.recordLibrary()
    }
    
    public func restore() -> Bool {
        Log("Make Attempt Restore the Node Properties DHTAddress, KeyPairs and Difficulty.")
        if let signInformation = self.silentSigner()?.fetchLibrary(),
//           let bookInformation = self.book.fetchLibrary(),
            let publicKeyForSignatureAsBase64String = signInformation["publicKeyForSignature"],
            let publicKeyForSignatureAsData = publicKeyForSignatureAsBase64String.base64DecodedData,
            let privateKeyForSignatureAsBase64String = signInformation["privateKeyForSignature"],
            let privateKeyForSignatureAsData = privateKeyForSignatureAsBase64String.base64DecodedData,
            let publicKeyForEncryptionAsBase64String = signInformation["publicKeyForEncryption"],
            let publicKeyForEncryptionAsData = publicKeyForEncryptionAsBase64String.base64DecodedData,
            let privateKeyForEncryptionAsBase64String = signInformation["privateKeyForEncryption"],
            let privateKeyForEncryptionAsData = privateKeyForEncryptionAsBase64String.base64DecodedData,
            let dhtAddressAsHexString = signInformation["dhtAddressAsHexString"]
        {
            Log("Node Information is Restorable.")
            let signer = Signer(publicKeyForSignatureAsData: publicKeyForSignatureAsData, privateKeyForSignatureAsData: privateKeyForSignatureAsData, dhtAddressAsHexString: dhtAddressAsHexString, publicKeyForEncryptionAsData: publicKeyForEncryptionAsData, privateKeyForEncryptionAsData: privateKeyForEncryptionAsData)
            self.setSigner(signer: signer)
            self.dhtAddressAsHexString = dhtAddressAsHexString
            if let binaryAddress = dhtAddressAsHexString.toData {
                self.binaryAddress = binaryAddress
            }
            return true
        } else {
            Log("Node Properties is NOT Cached.")
            return false
        }
    }
}
