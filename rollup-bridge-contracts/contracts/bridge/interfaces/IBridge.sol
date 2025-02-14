// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IBridge {
    /**
     *
     * Errors                *
     *
     */

    /// @dev Thrown when the given address is `address(0)`.
    error ErrorZeroAddress();

    /**
     *
     * Public View Functions *
     *
     */

    /// @notice The address of L1BridgeRouter/L2BridgeRouter contract.
    function router() external view returns (address);

    /// @notice The address of Bridge contract on other side (for L1Bridge it would be the bridge-address on L2 and for
    /// L2Bridge this would be the bridge-address on L1)
    function counterpartyBridge() external view returns (address);

    /// @notice The address of corresponding L1NilMessenger/L2NilMessenger contract.
    function messenger() external view returns (address);
}
