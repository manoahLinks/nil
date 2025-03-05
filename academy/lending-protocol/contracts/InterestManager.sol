// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@nilfoundation/smart-contracts/contracts/Nil.sol";
import "@nilfoundation/smart-contracts/contracts/NilTokenBase.sol";

// The InterestManager contract is responsible for providing the interest rate to be used in the lending protocol.
// It can be extended to calculate dynamic interest rates based on different parameters.
contract InterestManager {
    // The getInterestRate function returns a fixed interest rate of 5%
    // In a real-world scenario, this could be replaced with a dynamic calculation based on market conditions.
    function getInterestRate() public pure returns (uint256) {
        return 5; // Return a fixed interest rate of 5%
    }
}
