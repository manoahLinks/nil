// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IBridgeMessenger {
    /*//////////////////////////////////////////////////////////////////////////
                           ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Thrown when the given address is `address(0)`.
    error ErrorZeroAddress();

    /// @dev Thrown when the given hash is invalid.
    error ErrorInvalidHash();

    /// @dev Thrown when the given amount is invalid.
    error ErrorInvalidAmount();

    /// @dev Thrown when the given gas limit is invalid.
    error ErrorInvalidGasLimit();

    /**
     * @notice Pauses or unpauses the contract.
     * @dev This function allows the owner to pause or unpause the contract.
     * @param _status The pause status to update.
     */
    function setPause(bool _status) external;

    function acceptOwnership() external;
}
