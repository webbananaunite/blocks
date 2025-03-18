//
//  Signer.swift
//  blocks
//
//  Created by よういち on 2023/08/07.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation
//import CryptoKit
//import Security
import overlayNetwork
#if os(macOS) || os(iOS)
import CryptoKit
import Security
#elseif canImport(Glibc)
import Glibc
import Crypto
#elseif canImport(Musl)
import Musl
import Crypto
#endif

/*
 Key Store is NOT use on Linux.
 */
#if os(macOS) || os(iOS)
/*
 Storing Keys in Key Chain

 Thank:
 https://developer.apple.com/documentation/cryptokit/storing_cryptokit_keys_in_the_keychain#3369557
 */
extension OSStatus {
    /// A human readable message for the status.
    var message: String {
        return (SecCopyErrorMessageString(self, nil) as String?) ?? String(self)
    }
}

/*
 Store Crypt Key in Secured Key Store.
 */
struct GenericPasswordStore {
    /// Stores a CryptoKit key in the keychain as a generic password.
    func storeKey<T: SignatureKeyProtocol>(_ key: T, account: String) throws {
        // Treat the key data as a generic password.
        let query = [kSecClass: kSecClassGenericPassword,
                     kSecAttrAccount: account,
                     kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked,
                     kSecUseDataProtectionKeychain: true,
                     kSecValueData: key.rawRepresentation] as [String: Any]
        
        // Add the key data.
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.CanNotStoreToKeychain("Unable to store item: \(status.message)")
        }
    }
    
    /// Reads a CryptoKit key from the keychain as a generic password.
    func readKey<T: SignatureKeyProtocol>(account: String) throws -> T? {
        // Seek a generic password with the given account.
        let query = [kSecClass: kSecClassGenericPassword,
                     kSecAttrAccount: account,
                     kSecUseDataProtectionKeychain: true,
                     kSecReturnData: true] as [String: Any]
        
        // Find and cast the result as data.
        var item: CFTypeRef?
        switch SecItemCopyMatching(query as CFDictionary, &item) {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return try T(rawRepresentation: data)  // Convert back to a key.
        case errSecItemNotFound: return nil
        case let status: throw KeychainError.CanNotStoreToKeychain("Keychain read failed: \(status.message)")
        }
    }
    
    /// Stores a key in the keychain and then reads it back.
    func roundTrip<T: SignatureKeyProtocol>(_ key: T) throws -> T {
        // An account name for the key in the keychain.
        let account = "com.example.genericpassword.key"
        
        // Start fresh.
        try deleteKey(account: account)
        
        // Store and read it back.
        try storeKey(key, account: account)
        guard let key: T = try readKey(account: account) else {
            throw KeychainError.CanNotStoreToKeychain("Failed to locate stored key.")
        }
        return key
    }
    
    /// Removes any existing key with the given account.
    func deleteKey(account: String) throws {
        let query = [kSecClass: kSecClassGenericPassword,
                     kSecUseDataProtectionKeychain: true,
                     kSecAttrAccount: account] as [String: Any]
        switch SecItemDelete(query as CFDictionary) {
        case errSecItemNotFound, errSecSuccess: break // Okay to ignore
        case let status:
            throw KeychainError.CanNotStoreToKeychain("Unexpected deletion error: \(status.message)")
        }
    }
}
#endif

public protocol SignerProtocol {
    associatedtype PrivateKeyForSignatureType: SignaturePrivateKeyProtocol
    associatedtype PublicKeyForSignatureType: SignaturePublicKeyProtocol
    associatedtype PrivateKeyForEncryptionType: SignaturePrivateKeyProtocol
    associatedtype PublicKeyForEncryptionType: SignaturePublicKeyProtocol
    
    var accountStringLength: Int {
        get
    }
    var makerDhtAddressAsHexString: OverlayNetworkAddressAsHexString {
        get set
    }
    func newPrivateKey() -> PrivateKeyForSignatureType?
    func publicKey<PrivateKeyForSignatureType:SignaturePrivateKeyProtocol>(privateKey: PrivateKeyForSignatureType) -> PublicKeyForSignatureType?
    func publicKeyForExchange(privateKey: PrivateKeyForSignatureType) throws -> Data?
    func privateKeyForExchange(privateKey: PrivateKeyForSignatureType) throws -> Data?
    
    var privateKeyForSignature: PrivateKeyForSignatureType? {
        get set
    }
    var publicKeyForSignature: PublicKeyForSignatureType? {
        get set
    }
    var privateKeyForEncryption: PrivateKeyForEncryptionType? {
        get set
    }
    var publicKeyForEncryption: PublicKeyForEncryptionType? {
        get set
    }
    var base64EncodedPrivateKeyForSignatureString: String? {
        get
    }
    var base64EncodedPublicKeyForSignatureString: String? {
        get
    }
    
    var publicKeyAsData: PublicKey? {
        get
    }

    var base64EncodedPrivateKeyForEncryptionString: String? {
        get
    }
    var base64EncodedPublicKeyForEncryptionString: String? {
        get
    }
    init()
    init(publicKeyAsData: PublicKey, makerDhtAddressAsHexString: OverlayNetworkAddressAsHexString, publicKeyForEncryptionAsData: PublicKeyForEncryption?)
    init(newPrivateKeyOn makerDhtAddressAsHexString: String)
}
public extension SignerProtocol {
    var base64EncodedPrivateKeyForSignatureString: String? {
        return self.privateKeyForSignature?.rawRepresentation.base64String
    }
    var base64EncodedPublicKeyForSignatureString: String? {
        return self.publicKeyForSignature?.rawRepresentation.base64String
    }

    var publicKeyAsData: PublicKey? {
        return self.publicKeyForSignature?.rawRepresentation
    }

    var base64EncodedPrivateKeyForEncryptionString: String? {
        return self.privateKeyForEncryption?.rawRepresentation.base64String
    }
    var base64EncodedPublicKeyForEncryptionString: String? {
        return self.publicKeyForEncryption?.rawRepresentation.base64String
    }
    
    var accountStringLength: Int {
        90
    }
    
    /*
     Key for Signature
     */
    func newPrivateKey<PrivateKeyForSignatureType: SignaturePrivateKeyProtocol>() -> PrivateKeyForSignatureType? {
        return PrivateKeyForSignatureType()
    }
    
    func publicKey<PrivateKeyForSignatureType:SignaturePrivateKeyProtocol>(privateKey: PrivateKeyForSignatureType) -> PublicKeyForSignatureType? {
        return privateKey.public_key as? Self.PublicKeyForSignatureType
    }
    
    func publicKeyForExchange(privateKey: PrivateKeyForSignatureType) throws -> Data? {
        return privateKey.public_key.rawRepresentation
    }
    
    func privateKeyForExchange(privateKey: PrivateKeyForSignatureType) throws -> Data? {
        return privateKey.rawRepresentation
    }
    
    /*
     Key for Encryption
     */
    func newPrivateKeyForKeyAgreement<PrivateKeyForEncryptionType: SignaturePrivateKeyProtocol>() -> PrivateKeyForEncryptionType? {
        return PrivateKeyForEncryptionType()
    }
    
    func publicKeyForKeyAgreement<PrivateKeyForEncryptionType:SignaturePrivateKeyProtocol>(privateKey: PrivateKeyForEncryptionType) -> PublicKeyForEncryptionType? {
        return privateKey.public_key as? Self.PublicKeyForEncryptionType
    }
    
    func publicKeyForExchangeForKeyAgreement(privateKey: PrivateKeyForEncryptionType) throws -> Data? {
        return privateKey.public_key.rawRepresentation
    }
    
    func privateKeyForExchangeForKeyAgreement(privateKey: PrivateKeyForEncryptionType) throws -> Data? {
        return privateKey.rawRepresentation
    }
    
    init() {
        self.init()
        self.makerDhtAddressAsHexString = ""
        self.privateKeyForSignature = nil
        self.publicKeyForSignature = nil
        self.privateKeyForEncryption = nil
        self.publicKeyForEncryption = nil
    }
    
    init(newPrivateKeyOn makerDhtAddressAsHexString: String) {
        Log()
        self.init()
        self.makerDhtAddressAsHexString = makerDhtAddressAsHexString
        /*
         Generate Key for Signature
         */
        self.privateKeyForSignature = newPrivateKey()
        if let privateKeyForSignature = self.privateKeyForSignature {
            self.publicKeyForSignature = publicKey(privateKey: privateKeyForSignature)
        }
        /*
         Generate Key for Encryption
         */
        self.privateKeyForEncryption = newPrivateKeyForKeyAgreement()
        if let privateKeyForEncryption = self.privateKeyForEncryption {
            self.publicKeyForEncryption = publicKeyForKeyAgreement(privateKey: privateKeyForEncryption)
        }
        
        Log(self.makerDhtAddressAsHexString)
        Log(self.privateKeyForSignature?.rawRepresentation)
        Log(self.publicKeyForSignature?.rawRepresentation)
        Log(self.privateKeyForEncryption?.rawRepresentation)
        Log(self.publicKeyForEncryption?.rawRepresentation)
    }
    
    init(publicKeyAsData: PublicKey, makerDhtAddressAsHexString: OverlayNetworkAddressAsHexString, publicKeyForEncryptionAsData: PublicKeyForEncryption? = nil) {
        Log()
        self.init()
        do {
            self.publicKeyForSignature = try PublicKeyForSignatureType(rawRepresentation: publicKeyAsData.publicKeyToData)
            self.makerDhtAddressAsHexString = makerDhtAddressAsHexString
        } catch {
            Log(error)
        }
        if let publicKeyAsData = publicKeyForEncryptionAsData {
            do {
                self.publicKeyForSignature = try PublicKeyForSignatureType(rawRepresentation: publicKeyAsData.publicKeyForEncryptionToData)
                self.makerDhtAddressAsHexString = makerDhtAddressAsHexString
            } catch {
                Log(error)
            }
        }
    }
}

/*
 Use Signature & Encryption, Both.
 */
public protocol SignatureKeyProtocol {
    var rawRepresentation: Data {
        get
    }
    init<D>(rawRepresentation: D) throws where D : ContiguousBytes
}
public protocol SignaturePrivateKeyProtocol: SignatureKeyProtocol {
    var rawRepresentation: Data {
        get
    }
    var public_key: SignaturePublicKeyProtocol { get }

    init()
    init<D>(rawRepresentation: D) throws where D : ContiguousBytes
}
public protocol SignaturePublicKeyProtocol: SignatureKeyProtocol {
}

/*
 When use encryption method,
 Should be apply Protocol{EncryptedKeyTypeProtocol}
 
 Ed25519
 公開鍵は256ビット、署名は512ビット
 */

/*
 Signing Data to Signature
 */
extension Curve25519.Signing.PrivateKey: SignaturePrivateKeyProtocol {
    public var public_key: SignaturePublicKeyProtocol {
        return self.publicKey
    }
}
extension Curve25519.Signing.PublicKey: SignaturePublicKeyProtocol {
}

extension P256.Signing.PrivateKey: SignaturePrivateKeyProtocol {
    public init() {
        self.init(compactRepresentable: true)
    }
    
    public var public_key: SignaturePublicKeyProtocol {
        return self.publicKey
    }
}
extension P256.Signing.PublicKey: SignaturePublicKeyProtocol {
}

/*
 Exchanging Encrypted Data
 */
extension Curve25519.KeyAgreement.PrivateKey: SignaturePrivateKeyProtocol {
    public var public_key: SignaturePublicKeyProtocol {
        self.publicKey
    }
}
extension Curve25519.KeyAgreement.PublicKey: SignaturePublicKeyProtocol {
}

extension P256.KeyAgreement.PrivateKey: SignaturePrivateKeyProtocol {
    public init() {
        self.init(compactRepresentable: true)
    }
    
    public var public_key: SignaturePublicKeyProtocol {
        self.publicKey
    }
}
extension P256.KeyAgreement.PublicKey: SignaturePublicKeyProtocol {
}

extension SignatureKeyProtocol {
    /// A string version of the key for visual inspection.
    /// IMPORTANT: Never log the actual key data.
    public var description: String {
        return self.rawRepresentation.withUnsafeBytes { bytes in
            return "Key representation contains \(bytes.count) bytes."
        }
    }
}
extension Curve25519.KeyAgreement.PrivateKey: SignatureKeyProtocol {}
extension Curve25519.Signing.PrivateKey: SignatureKeyProtocol {}
//#now keychainへの保存から
//cf. KeyTest+Curve.swift

private enum KeychainError: Error {
    case CanNotStoreToKeychain(String?)
    case CanNotFetchFromKeychain
}
private enum EncryptionError: Error {
    case CanNotGenerateKeyForExchange(String?)
}
/*
 Values ex.
 公開鍵は256ビット、署名は512ビット

    self.makerDhtAddressAsHexString
    f87f3ce797b4fcdd28b33987751f821f251b61b7f16b31dbf38888e560a2ec0c1492fc41332ce86b330cc98cb2ac8bdcf482c61703ecfdcd58d7b94f2ae29876
 
    self.privateKeyForSignature?.rawRepresentation.base64String)
    kX2b0sueXpiur/2Y4ck36tN2vRWblmWs+P5HPvID7l4=  43文字　240+12+4=256
 
    self.publicKeyForSignature?.rawRepresentation.base64String)
    b813sQPUO9t8YQ7Qc0Px/nGaWjog+j0U1D7o/bNsP8M=　43文字　240+12+4=256
 
    self.privateKeyForEncryption?.rawRepresentation
    self.publicKeyForEncryption?.rawRepresentation
 */
public struct Signer: SignerProtocol {
    public init() {
        self.makerDhtAddressAsHexString = ""
        self.privateKeyForSignature = nil
        self.publicKeyForSignature = nil
        self.privateKeyForEncryption = nil
        self.publicKeyForEncryption = nil
    }

    public init(newPrivateKeyOn makerDhtAddressAsHexString: OverlayNetworkAddressAsHexString) {
        Log()
        self.init()
        self.makerDhtAddressAsHexString = makerDhtAddressAsHexString
        /*
         Generate Key for Signature
         */
        self.privateKeyForSignature = newPrivateKey()
        if let privateKeyForSignature = self.privateKeyForSignature {
            self.publicKeyForSignature = publicKey(privateKey: privateKeyForSignature)
        }
        /*
         Generate Key for Encryption
         */
        self.privateKeyForEncryption = newPrivateKeyForKeyAgreement()
        if let privateKeyForEncryption = self.privateKeyForEncryption {
            self.publicKeyForEncryption = publicKeyForKeyAgreement(privateKey: privateKeyForEncryption)
        }
    }
    
    public init(publicKeyAsData: PublicKey, makerDhtAddressAsHexString: OverlayNetworkAddressAsHexString, publicKeyForEncryptionAsData: PublicKeyForEncryption? = nil) {
        Log()
        self.init()
        do {
            self.publicKeyForSignature = try PublicKeyForSignatureType(rawRepresentation: publicKeyAsData.publicKeyToData)
            self.makerDhtAddressAsHexString = makerDhtAddressAsHexString
        } catch {
            Log(error)
        }
        if let publicKeyForEncryptionAsData = publicKeyForEncryptionAsData {
            do {
                self.publicKeyForSignature = try PublicKeyForSignatureType(rawRepresentation: publicKeyForEncryptionAsData.publicKeyForEncryptionToData)
                self.makerDhtAddressAsHexString = makerDhtAddressAsHexString
            } catch {
                Log(error)
            }
        }
    }

    public init(publicKeyForSignatureAsData: PublicKey, privateKeyForSignatureAsData: PrivateKey, dhtAddressAsHexString: OverlayNetworkAddressAsHexString, publicKeyForEncryptionAsData: PublicKeyForEncryption, privateKeyForEncryptionAsData: PrivateKeyForEncryption) {
        Log()
        self.init()
        do {
            self.publicKeyForSignature = try PublicKeyForSignatureType(rawRepresentation: publicKeyForSignatureAsData.publicKeyToData)
            self.privateKeyForSignature = try PrivateKeyForSignatureType(rawRepresentation: privateKeyForSignatureAsData.privateKeyToData)
        } catch {
            Log(error)
        }
        do {
            self.publicKeyForEncryption = try PublicKeyForEncryptionType(rawRepresentation: publicKeyForEncryptionAsData.publicKeyForEncryptionToData)
            self.privateKeyForEncryption = try PrivateKeyForEncryptionType(rawRepresentation: privateKeyForEncryptionAsData.privateKeyForEncryptionToData)
        } catch {
            Log(error)
        }
        self.makerDhtAddressAsHexString = dhtAddressAsHexString
    }

    /*
     MakerID:
     97Oh83BiAfrK1dMtIkbQNqHReJ9/Mx
     Wz7Tt6RBJ6D2MJdyyFhAVRjwlpL9cF
     rIyqZ5dfxsSKWusbru4gZHKIBg==
     30+30+26 = 86文字
     
     Curve25519
     Key (Signature, Exchange Encryption Data, Private, Public):
     kX2b0sueXpiur/2Y4ck36tN2vRWblmWs+P5HPvID7l4=  43文字　240+12+4=256
     */
    public var makerDhtAddressAsHexString: OverlayNetworkAddressAsHexString
    public var privateKeyForSignature: Curve25519.Signing.PrivateKey?
    public var publicKeyForSignature: Curve25519.Signing.PublicKey?
    public var privateKeyForEncryption: Curve25519.KeyAgreement.PrivateKey?
    public var publicKeyForEncryption: Curve25519.KeyAgreement.PublicKey?
    
    /*
     Account for Amount of Total Money Supply
     
     As Doing Credit Creation, Use Transaction#withdrawalDhtAddressOnLeft = Signer#moneySupplyUnMoverAccount.
     
     ex. 
     Credit Creation (Booker Fee, Taker Fee, Basic Income) transaction: =Money Supply
     -----------------|-----------------
     Total Money Supply   Credit Account
     1000                 1000
     "-"                  "eoKihAfoads83ioaoid"
     -----------------|-----------------
     */
    static let moneySupplyUnMoverAccount = "-"  //Account for detect Total Money Supply.

    enum SignatureError: Error {
        case NotSupportedKeyFormat
        case CanNotSign(String?)
        case CanNotVerify(String?)
    }

    /*
     Data as signed one,
        Make 平文 self.data(using: .utf8).
     */
    public func sign(contentAsData: Data) throws -> Signature? {
        Log()
        do {
            guard let privateKey = self.privateKeyForSignature else {
                Log()
                return nil
            }
            Log("Sign data. --Validation")
            Log("privateKey: \(privateKey.rawRepresentation.base64String)")
            Log("contentData(hashed): \(contentAsData.base64String)")
            Log("publickey: \(self.publicKeyForSignature?.rawRepresentation.base64String)")
            let signature = try privateKey.signature(for: contentAsData)
            Log("signature: \(signature.base64String)")
            Log("signed data: \(contentAsData.base64String)")
            return signature
        } catch {
            Log(error)
        }
        return nil
    }
    
    public func verify(data: Data, signature: Signature) throws -> Bool {
        Log()
        guard let publicKey = self.publicKeyForSignature else {
            Log()
            return false
        }
        Log("Verify data. --Validation")
        Log("publicKey: \(publicKey.rawRepresentation.base64String)")
        Log("signature: \(signature.toString)")
        Log("verify data: \(data.base64String)")
        return publicKey.isValidSignature(signature.signatureToData, for: data)
    }
    
    /*
     Encryption
     */
    public func encrypt(message: Data, peerPublicKeyForEncryption: PublicKeyForEncryptionType) -> AES.GCM.SealedBox? {
        do {
            if let sharedSecret = try self.privateKeyForEncryption?.sharedSecretFromKeyAgreement(with: peerPublicKeyForEncryption) {
                let aesKey = sharedSecret.x963DerivedSymmetricKey(using: SHA512.self, sharedInfo: Data.DataNull, outputByteCount: 64)
                let sealedMessage = try AES.GCM.seal(message, using: aesKey)
                return sealedMessage
            }
        } catch {
            Log(error)
        }
        return nil
    }
    
    public func decrypt(combinedSealedBox: Data, peerPublicKeyForEncryption: PublicKeyForEncryptionType) -> Data? {
        do {
            if let sharedSecret = try self.privateKeyForEncryption?.sharedSecretFromKeyAgreement(with: peerPublicKeyForEncryption) {
                let sealedBox = try AES.GCM.SealedBox(combined: combinedSealedBox)
                let aesKey = sharedSecret.x963DerivedSymmetricKey(using: SHA512.self, sharedInfo: Data.DataNull, outputByteCount: 64)
                let message = try AES.GCM.open(sealedBox, using: aesKey)
                return message
            }
        } catch {
            Log(error)
        }
        return nil
    }

    /*
     Store Book to Device's Storage.
     
     Format: Json
     */
    private var content: Data {
        var jsonString = """
{"publicKeyForSignature":"\(self.publicKeyForSignature?.rawRepresentation.base64String ?? "")",
"privateKeyForSignature":"\(self.privateKeyForSignature?.rawRepresentation.base64String ?? "")",
"publicKeyForEncryption":"\(self.publicKeyForEncryption?.rawRepresentation.base64String ?? "")",
"privateKeyForEncryption":"\(self.privateKeyForEncryption?.rawRepresentation.base64String ?? "")",
"dhtAddressAsHexString":"\(self.makerDhtAddressAsHexString)"}
"""
        let data = jsonString.utf8DecodedData
        if let data = data {
            return data
        }
        return Data.DataNull
    }
    
    private let archivedDirectory = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first! + "/signer/"
    private let archiveFile = "signer.json"
    private var archiveFilePath: String {
        self.archivedDirectory + self.archiveFile
    }
    public func recordLibrary() {Log()
        do {
            if !FileManager.default.fileExists(atPath: self.archivedDirectory) {
                do {
                    try FileManager.default.createDirectory(atPath: self.archivedDirectory, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    Log()
                }
            }
            let storeUrl = URL(fileURLWithPath: self.archiveFilePath)
            let jsonAsData = self.content
            Log("\(jsonAsData.utf8String ?? "")")
            try jsonAsData.append(to: storeUrl, truncate: true)
        } catch {
            Log("Save Json Error \(error)")
        }
    }

    public func isCached() -> Bool {
        Log()
        if !FileManager.default.fileExists(atPath: self.archiveFilePath) {
            Log("No Cached")
            return false
        }
        Log("Cached")
        return true
    }

    public func fetchLibrary() -> [String: String]? {
        Log()
        if self.isCached() {
            Log()
            do {
                let url = URL(fileURLWithPath: self.archiveFilePath)
                let data = try Data(contentsOf: url)
                Log("\(data.utf8String ?? "")")
                if let jsonAsString = data.utf8String {
                    return jsonAsString.jsonToDictionary
                }
            } catch {
                Log("Error Fetching Json Data: \(error)")
            }
        }
        return nil
    }
}
