//
//  ChainSelectionTest.swift
//  blocksTests
//
//  Created by Codex on 2026/05/24.
//

import XCTest
@testable import blocks

final class ChainSelectionTest: XCTestCase {

    func testDoesNotReplaceLegitimateChainByFixedFourBlockCount() {
        var book = Book(signature: Data.DataNull)
        let branchPoint = block(difficulty: 16)
        book.blocks = [
            branchPoint,
            block(difficulty: 20),
            block(difficulty: 20),
            block(difficulty: 20)
        ]
        let weakerFourBlockBranch = [
            block(difficulty: 16),
            block(difficulty: 16),
            block(difficulty: 16),
            block(difficulty: 16)
        ]

        XCTAssertFalse(book.shouldReplaceLegitimateChain(branchPointIndex: 0, candidateBranch: weakerFourBlockBranch))
    }

    func testReplacesLegitimateChainWhenCandidateHasMoreCumulativeWork() {
        var book = Book(signature: Data.DataNull)
        let branchPoint = block(difficulty: 16)
        book.blocks = [
            branchPoint,
            block(difficulty: 16),
            block(difficulty: 16),
            block(difficulty: 16),
            block(difficulty: 16)
        ]
        let shorterStrongerBranch = [
            block(difficulty: 19)
        ]

        XCTAssertTrue(book.shouldReplaceLegitimateChain(branchPointIndex: 0, candidateBranch: shorterStrongerBranch))
    }

    private func block(difficulty: Int) -> Block {
        var block = Block.genesis
        block.difficultyAsNonceLeadingZeroLength = difficulty
        return block
    }
}
