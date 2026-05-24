//
//  TransactionSignatureTest.swift
//  blocksTests
//
//  Created by Codex on 2026/05/24.
//

import XCTest
@testable import blocks
import overlayNetwork

final class TransactionSignatureTest: XCTestCase {

    func testSignatureCoversCanonicalTransactionFields() throws {
        let makerAddress = "maker-account" as OverlayNetworkAddressAsHexString
        let signer = Signer(newPrivateKeyOn: makerAddress)
        guard let publicKey = signer.publicKeyAsData else {
            XCTFail("Signer should have a public key.")
            return
        }
        let claimObject = ClaimOnPay.Object(destination: "deposit-account", description: "booker fee")
        var transaction = Pay(
            claim: ClaimOnPay.bookerFee,
            claimObject: claimObject,
            makerDhtAddressAsHexString: "maker-account",
            publicKey: publicKey,
            book: Book(signature: Data.DataNull),
            signer: signer,
            transactionId: "BK-test-transaction",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            debitOnLeft: Decimal(10),
            creditOnRight: Decimal(10),
            withdrawalDhtAddressOnLeft: "maker-account",
            depositDhtAddressOnRight: "deposit-account"
        )

        guard let signature = transaction.signature else {
            XCTFail("Transaction should be signed.")
            return
        }
        let signedData = try XCTUnwrap(transaction.canonicalSignaturePayloadData?.hashedData?.toData)

        XCTAssertTrue(try transaction.verify(data: signedData, signature: signature, signer: signer))

        transaction.depositDhtAddressOnRight = "tampered-deposit-account"
        let tamperedData = try XCTUnwrap(transaction.canonicalSignaturePayloadData?.hashedData?.toData)

        XCTAssertFalse(try transaction.verify(data: tamperedData, signature: signature, signer: signer))
    }
}
