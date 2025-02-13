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

  /*****************************
   * Public Mutating Functions *
   *****************************/

  /// @notice Send cross chain message from L1 to L2 or L2 to L1.
  /// @param target The address of account who receive the message.
  /// @param value The amount of ether passed when call target contract.
  /// @param message The content of the message.
  /// @param gasLimit Gas limit required to complete the message relay on corresponding chain.
  function sendMessage(address target, uint256 value, bytes calldata message, uint256 gasLimit) external payable;

  /// @notice Send cross chain message from L1 to L2 or L2 to L1.
  /// @param target The address of account who receive the message.
  /// @param value The amount of ether passed when call target contract.
  /// @param message The content of the message.
  /// @param gasLimit Gas limit required to complete the message relay on corresponding chain.
  /// @param refundAddress The address of account who will receive the refunded fee.
  function sendMessage(
    address target,
    uint256 value,
    bytes calldata message,
    uint256 gasLimit,
    address refundAddress
  ) external payable;
}
