// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@nilfoundation/smart-contracts/contracts/Nil.sol";
import "@nilfoundation/smart-contracts/contracts/NilTokenBase.sol";

// The Oracle contract provides token price data to the lending protocol.
// It is used to fetch the price of tokens (e.g., USDT, ETH) used for collateral calculations in the lending process.
contract Oracle is NilBase {
    // Mapping to store the price of each token (TokenId => price)
    mapping(TokenId => uint256) public rates;

    // Function to set the price of a token
    // This allows the price of tokens to be updated in the Oracle contract.
    // Only authorized entities (e.g., the contract owner or admin) should be able to set the price.
    function setPrice(TokenId token, uint256 price) public {
        rates[token] = price; // Store the price of the token in the rates mapping
    }

    // Function to retrieve the price of a token
    // This allows other contracts (like LendingPool) to access the current price of a token.
    function getPrice(TokenId token) public view returns (uint256) {
        return rates[token]; // Return the price of the specified token
    }
}
