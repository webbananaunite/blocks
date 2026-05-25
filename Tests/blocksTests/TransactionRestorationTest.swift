//
//  TransactionRestorationTest.swift
//  blocksTests
//
//  Created by Codex on 2026/05/24.
//

import XCTest
@testable import blocks
import overlayNetwork

final class TransactionRestorationTest: XCTestCase {

    func testRestoresReceivedPayTransaction() throws {
        let signer = Signer(newPrivateKeyOn: "pay-maker" as OverlayNetworkAddressAsHexString)
        guard let publicKey = signer.publicKeyAsData else {
            XCTFail("Signer should have a public key.")
            return
        }
        let transaction = try XCTUnwrap(TransactionType.pay.construct(
            claim: ClaimOnPay.bookerFee,
            claimObject: ClaimOnPay.Object(destination: "pay-destination", description: "pay description"),
            makerDhtAddressAsHexString: signer.makerDhtAddressAsHexString,
            publicKey: publicKey,
            book: Book(signature: Data.DataNull),
            signer: signer,
            transactionId: "BK-pay-restore",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            debitOnLeft: Decimal(10),
            creditOnRight: Decimal(10),
            withdrawalDhtAddressOnLeft: "pay-maker",
            depositDhtAddressOnRight: "pay-destination"
        ))
        let receivedSigner = Signer(publicKeyAsData: publicKey, makerDhtAddressAsHexString: signer.makerDhtAddressAsHexString)

        let restored = Transactions.Maker(book: Book(signature: Data.DataNull), string: "[\(transaction.jsonString)]", signer: receivedSigner).stringToTransactions
        let restoredPay = try XCTUnwrap(restored?.first as? Pay)
        let restoredObject = try XCTUnwrap(restoredPay.claimObject as? ClaimOnPay.Object)

        XCTAssertEqual(restoredPay.claim.rawValue, ClaimOnPay.bookerFee.rawValue)
        XCTAssertEqual(restoredObject.destination.toString, "pay-destination")
        XCTAssertEqual(restoredObject.description, "pay description")
    }

    func testRestoresReceivedFactTransaction() throws {
        let signer = Signer(newPrivateKeyOn: "fact-maker" as OverlayNetworkAddressAsHexString)
        guard let publicKey = signer.publicKeyAsData else {
            XCTFail("Signer should have a public key.")
            return
        }
        let transaction = try XCTUnwrap(TransactionType.fact.construct(
            claim: ClaimOnFact.a,
            claimObject: ClaimOnFact.Object(destination: "fact-destination", description: "fact description"),
            makerDhtAddressAsHexString: signer.makerDhtAddressAsHexString,
            publicKey: publicKey,
            book: Book(signature: Data.DataNull),
            signer: signer,
            transactionId: "BK-fact-restore",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            debitOnLeft: Decimal(1),
            creditOnRight: Decimal(1),
            withdrawalDhtAddressOnLeft: "fact-maker",
            depositDhtAddressOnRight: "fact-destination"
        ))
        let receivedSigner = Signer(publicKeyAsData: publicKey, makerDhtAddressAsHexString: signer.makerDhtAddressAsHexString)

        let restored = Transactions.Maker(book: Book(signature: Data.DataNull), string: "[\(transaction.jsonString)]", signer: receivedSigner).stringToTransactions
        let restoredFact = try XCTUnwrap(restored?.first as? Fact)
        let restoredObject = try XCTUnwrap(restoredFact.claimObject as? ClaimOnFact.Object)

        XCTAssertEqual(restoredFact.claim.rawValue, ClaimOnFact.a.rawValue)
        XCTAssertEqual(restoredObject.destination.toString, "fact-destination")
        XCTAssertEqual(restoredObject.description, "fact description")
    }
}
