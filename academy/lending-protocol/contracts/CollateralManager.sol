// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@nilfoundation/smart-contracts/contracts/Nil.sol";
import "@nilfoundation/smart-contracts/contracts/NilTokenBase.sol";

// The GlobalLedger contract is responsible for tracking user deposits and loans in the lending protocol.
// It stores the deposit balances for users and keeps track of the loans each user has taken.
contract GlobalLedger {
    // Mapping of user addresses to their token deposits (token -> amount)
    mapping(address => mapping(TokenId => uint256)) public deposits;

    // Mapping of user addresses to their loans (loan amount and loan token)
    mapping(address => Loan) public loans;

    // Struct to store loan details: amount and the token type
    struct Loan {
        uint256 amount; // Amount of the loan
        TokenId token; // Token used for the loan (USDT or ETH)
    }

    // Function to record a user's deposit into the ledger
    // Increases the deposit balance for the user for the specified token
    function recordDeposit(address user, TokenId token, uint256 amount) public {
        // Increase the user's deposit balance by the deposited amount
        deposits[user][token] += amount;
    }

    // Function to fetch a user's deposit balance for a specific token
    // Returns the amount of the token deposited by the user
    function getDeposit(
        address user,
        TokenId token
    ) public view returns (uint256) {
        return deposits[user][token]; // Return the deposit amount for the given user and token
    }

    // Function to record a user's loan in the ledger
    // Stores the amount of the loan and the token type used for the loan
    function recordLoan(address user, TokenId token, uint256 amount) public {
        // Record the loan by storing the amount and token type for the user
        loans[user] = Loan(amount, token);
    }

    // Function to get a user's loan details
    // Returns the loan amount and the token used for the loan
    function getLoanDetails(
        address user
    ) public view returns (uint256, TokenId) {
        // Return the loan amount and token type from the user's loan details
        return (loans[user].amount, loans[user].token);
    }
}
