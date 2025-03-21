// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IBridgeMessenger } from "../../interfaces/IBridgeMessenger.sol";
import { NilConstants } from "../../../common/libraries/NilConstants.sol";

/// @title IL2BridgeMessenger
/// @notice Interface for the L2BridgeMessenger contract which handles cross-chain messaging between L1 and L2.
/// @dev This interface defines the functions and events for finalizing deposit messages, sending messages to L1, and initiating withdrawals
interface IL2BridgeMessenger is IBridgeMessenger {
  /*//////////////////////////////////////////////////////////////////////////
                             ERRORS
    //////////////////////////////////////////////////////////////////////////*/

  /// @dev Invalid owner address.
  error ErrorInvalidOwner();

  /// @dev Invalid default admin address.
  error ErrorInvalidDefaultAdmin();

  /// @dev Invalid address.
  error ErrorInvalidAddress();

  error ErrorBridgeNotAuthorised();

  /// @notice Thrown when a bridge interface is invalid.
  error ErrorInvalidBridgeInterface();

  /// @notice Thrown when a bridge is already authorized.
  error ErrorBridgeAlreadyAuthorized();

  error ErrorInvalidCounterpartBridgeMessenger();

  error ErrorDuplicateMessageRelayed(bytes32 messageHash);

  error ErrorInvalidMerkleRoot();

  /*//////////////////////////////////////////////////////////////////////////
                             EVENTS
    //////////////////////////////////////////////////////////////////////////*/

  event MessageRelayFailed(bytes32 indexed messageHash);

  event MessageRelaySuccessful(bytes32 indexed messageHash);

  /*//////////////////////////////////////////////////////////////////////////
                         PUBLIC CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

  /// @notice Get the list of authorized bridges
  /// @return The list of authorized bridge addresses.
  function getAuthorizedBridges() external view returns (address[] memory);

  function computeMessageHash(
    address _messageSender,
    address _messageTarget,
    uint256 _value,
    uint256 _messageNonce,
    bytes memory _message
  ) external pure returns (bytes32);

  /*//////////////////////////////////////////////////////////////////////////
                         PUBLIC MUTATION FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

  /// @notice receive realyedMessage originated from L1BridgeMessenger via Relayer
  /// @dev only authorized smart-account on nil-shard can relayMessage to Bridge on NilShard
  /// @param messageSender The address of the sender of the message.
  /// @param messageTarget The address of the recipient of the message.
  /// @param value The msg.value passed to the message call.
  /// @param messageNonce The nonce of the message to avoid replay attack.
  /// @param message The content of the message.
  function relayMessage(
    address messageSender,
    address messageTarget,
    NilConstants.MessageType messageType,
    uint256 value,
    uint256 messageNonce,
    bytes calldata message
  ) external;

  /// @notice Send cross chain message Nil to L1.
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

  /*//////////////////////////////////////////////////////////////////////////
                         OWNER RESTRICTED FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

  /// @notice Authorize a bridge addresses
  /// @param bridges The array of addresses of the bridges to authorize.
  function authorizeBridges(address[] memory bridges) external;

  /// @notice Authorize a bridge address
  /// @param bridge The address of the bridge to authorize.
  function authorizeBridge(address bridge) external;

  /// @notice Revoke authorization of a bridge address
  /// @param bridge The address of the bridge to revoke.
  function revokeBridgeAuthorization(address bridge) external;

  /**
   * @notice Pauses or unpauses the contract.
   * @dev This function allows the owner to pause or unpause the contract.
   * @param _status The pause status to update.
   */
  function setPause(bool _status) external;
}
