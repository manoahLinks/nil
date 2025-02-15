// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IBridgeMessenger } from "../../interfaces/IBridgeMessenger.sol";

/// @title IL1BridgeMessenger
/// @notice Interface for the L1BridgeMessenger contract which handles cross-chain messaging between L1 and L2.
/// @dev This interface defines the functions and events for managing deposit messages, sending messages, and canceling deposits.
interface IL1BridgeMessenger is IBridgeMessenger {
  /*//////////////////////////////////////////////////////////////////////////
                             ERRORS
    //////////////////////////////////////////////////////////////////////////*/

  /// @notice Thrown when a deposit message already exists.
  /// @param messageHash The hash of the deposit message.
  error DepositMessageAlreadyExist(bytes32 messageHash);

  /// @notice Thrown when a deposit message does not exist.
  /// @param messageHash The hash of the deposit message.
  error DepositMessageDoesNotExist(bytes32 messageHash);

  /// @notice Thrown when a deposit message is already cancelled.
  /// @param messageHash The hash of the deposit message.
  error DepositMessageAlreadyCancelled(bytes32 messageHash);

  /// @notice Thrown when a deposit message is not expired.
  /// @param messageHash The hash of the deposit message.
  error DepositMessageNotExpired(bytes32 messageHash);

  /// @notice Thrown when a message hash is not in the queue.
  /// @param messageHash The hash of the deposit message.
  error MessageHashNotInQueue(bytes32 messageHash);

  /// @notice Thrown when the max message processing time is invalid.
  error InvalidMaxMessageProcessingTime();

  /// @notice Thrown when the message cancel delta time is invalid.
  error InvalidMessageCancelDeltaTime();

  /// @notice Thrown when a bridge interface is invalid.
  error InvalidBridgeInterface();

  /// @notice Thrown when a bridge is already authorized.
  error BridgeAlreadyAuthorized();

  /// @notice Thrown when a bridge is not authorized.
  error BridgeNotAuthorized();

  /// @notice Thrown when any address other than l1NilRollup is attempting to remove messages from queue
  error NotAuthorizedToPopMessages();

  /*//////////////////////////////////////////////////////////////////////////
                             EVENTS
    //////////////////////////////////////////////////////////////////////////*/

  /// @notice Emitted when a message is sent.
  /// @param from The address of the sender.
  /// @param to The address of the receiver.
  /// @param depositType The type of the deposit.
  /// @param amount The amount of the deposit.
  /// @param messageNonce The nonce of the message.
  /// @param gasLimit The gas limit for processing the message.
  /// @param expiryTime The expiry time of the message.
  /// @param message The encoded message data.
  event MessageSent(
    address indexed from,
    address indexed to,
    DepositType indexed depositType,
    uint256 amount,
    uint256 messageNonce,
    uint256 gasLimit,
    uint256 expiryTime,
    bytes message
  );

  /// @notice Emitted when a deposit message is cancelled.
  /// @param messageHash The hash of the deposit message that was cancelled.
  event DepositMessageCancelled(bytes32 messageHash);

  /*//////////////////////////////////////////////////////////////////////////
                             MESSAGE STRUCTS   
    //////////////////////////////////////////////////////////////////////////*/

  /// @notice Enum representing the type of deposit.
  enum DepositType {
    ERC20,
    WETH,
    ETH
  }

  /// @notice Struct representing a deposit message.
  struct DepositMessage {
    address from; /// @notice The address of the sender.
    uint256 nonce; /// @notice The nonce of the deposit message.
    uint256 gasLimit; /// @notice The gas limit for processing the message.
    uint256 expiryTime; /// @notice The expiry time of the deposit message.
    bytes message; /// @notice The encoded message data.
    bool isCancelled; /// @notice Whether the deposit message is cancelled.
    DepositType depositType; /// @notice The type of the deposit.
  }

  /// @notice Gets the current deposit nonce.
  /// @return The current deposit nonce.
  function getCurrentDepositNonce() external view returns (uint256);

  /// @notice Gets the next deposit nonce.
  /// @return The next deposit nonce.
  function getNextDepositNonce() external view returns (uint256);

  /// @notice Gets the deposit type for a given message hash.
  /// @param msgHash The hash of the deposit message.
  /// @return depositType The type of the deposit.
  function getDepositType(bytes32 msgHash) external view returns (DepositType depositType);

  /// @notice Gets the deposit message for a given message hash.
  /// @param msgHash The hash of the deposit message.
  /// @return depositMessage The deposit message details.
  function getDepositMessage(bytes32 msgHash) external view returns (DepositMessage memory depositMessage);

  /// @notice Get the list of authorized bridges
  /// @return The list of authorized bridge addresses.
  function getAuthorizedBridges() external view returns (address[] memory);

  /*//////////////////////////////////////////////////////////////////////////
                           PUBLIC MUTATING FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

  /// @notice Send cross chain message from L1 to L2 or L2 to L1.
  /// @param depositType The depositType enum value
  /// @param target The address of account who receive the message.
  /// @param value The amount of ether passed when call target contract.
  /// @param message The content of the message.
  /// @param gasLimit Gas limit required to complete the message relay on corresponding chain.
  function sendMessage(
    DepositType depositType,
    address target,
    uint256 value,
    bytes calldata message,
    uint256 gasLimit
  ) external payable;

  /// @notice Send cross chain message from L1 to L2 or L2 to L1.
  /// @param depositType The depositType enum value
  /// @param target The address of account who receive the message.
  /// @param value The amount of ether passed when call target contract.
  /// @param message The content of the message.
  /// @param gasLimit Gas limit required to complete the message relay on corresponding chain.
  /// @param refundAddress The address of account who will receive the refunded fee.
  function sendMessage(
    DepositType depositType,
    address target,
    uint256 value,
    bytes calldata message,
    uint256 gasLimit,
    address refundAddress
  ) external payable;

  /// @notice Cancels a deposit message.
  /// @param messageHash The hash of the deposit message to cancel.
  function cancelDeposit(bytes32 messageHash) external;

  /*//////////////////////////////////////////////////////////////////////////
                           RESTRICTED FUNCTIONS
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

  /// @notice remove a list of messageHash values from the depositMessageQueue.
  /// @dev messages are always popped from the queue in FIFIO Order
  /// @param messageCount number of messages to be removed from the queue
  function popMessages(uint256 messageCount) external;
}
