//
//  CreditCreationValidationTest.swift
//  blocksTests
//
//  Created by Codex on 2026/05/24.
//

import XCTest
@testable import blocks
import overlayNetwork

final class CreditCreationValidationTest: XCTestCase {

    func testBookerFeeCreditCreationValidatesWithoutExistingBalance() throws {
        let signer = Signer(newPrivateKeyOn: "booker-account" as OverlayNetworkAddressAsHexString)
        guard let publicKey = signer.publicKeyAsData else {
            XCTFail("Signer should have a public key.")
            return
        }
        let fee = ClaimOnPay.bookerFee.fee
        let transaction = Pay(
            claim: ClaimOnPay.bookerFee,
            claimObject: ClaimOnPay.Object(destination: "booker-account"),
            makerDhtAddressAsHexString: "booker-account",
            publicKey: publicKey,
            book: Book(signature: Data.DataNull),
            signer: signer,
            transactionId: "BK-booker-fee",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            debitOnLeft: fee,
            creditOnRight: fee,
            withdrawalDhtAddressOnLeft: Signer.moneySupplyUnMoverAccount,
            depositDhtAddressOnRight: "booker-account"
        )

        XCTAssertTrue(transaction.validate(branchChainHash: nil, indexInBranchChain: nil))
    }

    func testRegularTransactionStillRequiresExistingBalance() throws {
        let signer = Signer(newPrivateKeyOn: "maker-account" as OverlayNetworkAddressAsHexString)
        guard let publicKey = signer.publicKeyAsData else {
            XCTFail("Signer should have a public key.")
            return
        }
        let transaction = Pay(
            claim: ClaimOnPay.bookerFee,
            claimObject: ClaimOnPay.Object(destination: "deposit-account"),
            makerDhtAddressAsHexString: "maker-account",
            publicKey: publicKey,
            book: Book(signature: Data.DataNull),
            signer: signer,
            transactionId: "BK-regular-payment",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            debitOnLeft: Decimal(10),
            creditOnRight: Decimal(10),
            withdrawalDhtAddressOnLeft: "maker-account",
            depositDhtAddressOnRight: "deposit-account"
        )

        XCTAssertFalse(transaction.validate(branchChainHash: nil, indexInBranchChain: nil))
    }
}
