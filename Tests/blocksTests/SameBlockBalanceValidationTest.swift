//
//  SameBlockBalanceValidationTest.swift
//  blocksTests
//
//  Created by Codex on 2026/05/24.
//

import XCTest
@testable import blocks
import overlayNetwork

final class SameBlockBalanceValidationTest: XCTestCase {

    func testRejectsSecondSpendWhenSameBlockTotalExceedsBalance() throws {
        let signer = Signer(newPrivateKeyOn: "maker-account" as OverlayNetworkAddressAsHexString)
        let book = try fundedBook(for: signer, amount: Decimal(102))
        let firstSpend = try payment(from: signer, book: book, id: "BK-first-spend", amount: Decimal(60))
        let secondSpend = try payment(from: signer, book: book, id: "BK-second-spend", amount: Decimal(60))

        XCTAssertTrue(firstSpend.validate(branchChainHash: nil, indexInBranchChain: nil))
        XCTAssertFalse(secondSpend.validate(branchChainHash: nil, indexInBranchChain: nil, transactionsInSameBlock: [firstSpend]))
    }

    func testAllowsSameBlockSpendsWithinAvailableBalance() throws {
        let signer = Signer(newPrivateKeyOn: "maker-account" as OverlayNetworkAddressAsHexString)
        let book = try fundedBook(for: signer, amount: Decimal(102))
        let firstSpend = try payment(from: signer, book: book, id: "BK-first-spend", amount: Decimal(40))
        let secondSpend = try payment(from: signer, book: book, id: "BK-second-spend", amount: Decimal(60))

        XCTAssertTrue(firstSpend.validate(branchChainHash: nil, indexInBranchChain: nil))
        XCTAssertTrue(secondSpend.validate(branchChainHash: nil, indexInBranchChain: nil, transactionsInSameBlock: [firstSpend]))
    }

    private func fundedBook(for signer: Signer, amount: Decimal) throws -> Book {
        let publicKey = try XCTUnwrap(signer.publicKeyAsData)
        let credit = Pay(
            claim: ClaimOnPay.bookerFee,
            claimObject: ClaimOnPay.Object(destination: signer.makerDhtAddressAsHexString),
            makerDhtAddressAsHexString: signer.makerDhtAddressAsHexString,
            publicKey: publicKey,
            book: Book(signature: Data.DataNull),
            signer: signer,
            transactionId: "BK-initial-credit",
            date: Date(timeIntervalSince1970: 1_700_000_000),
            debitOnLeft: amount,
            creditOnRight: amount,
            withdrawalDhtAddressOnLeft: Signer.moneySupplyUnMoverAccount,
            depositDhtAddressOnRight: signer.makerDhtAddressAsHexString.toString
        )

        var block = Block.genesis
        block.transactions = [credit]

        var book = Book(signature: Data.DataNull)
        book.blocks = [block]
        return book
    }

    private func payment(from signer: Signer, book: Book, id: TransactionIdentification, amount: Decimal) throws -> Pay {
        let publicKey = try XCTUnwrap(signer.publicKeyAsData)
        return Pay(
            claim: ClaimOnPay.bookerFeeReply,
            claimObject: ClaimOnPay.Object(destination: "deposit-account"),
            makerDhtAddressAsHexString: signer.makerDhtAddressAsHexString,
            publicKey: publicKey,
            book: book,
            signer: signer,
            transactionId: id,
            date: Date(timeIntervalSince1970: 1_700_000_100),
            debitOnLeft: amount,
            creditOnRight: amount,
            withdrawalDhtAddressOnLeft: signer.makerDhtAddressAsHexString.toString,
            depositDhtAddressOnRight: "deposit-account"
        )
    }
}
