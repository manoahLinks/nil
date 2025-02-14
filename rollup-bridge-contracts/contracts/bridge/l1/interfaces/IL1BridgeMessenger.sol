// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IBridgeMessenger } from "../../interfaces/IBridgeMessenger.sol";

interface IL1BridgeMessenger is IBridgeMessenger {
  /*//////////////////////////////////////////////////////////////////////////
                             ERRORS
    //////////////////////////////////////////////////////////////////////////*/

  error DepositMessageAlreadyExist(bytes32 messageHash);
  error DepositMessageDoesNotExist(bytes32 messageHash);
  error DepositMessageAlreadyCancelled(bytes32 messageHash);
  error DepositMessageNotExpired(bytes32 messageHash);
  error MessageHashNotInQueue(bytes32 messageHash);

  /*//////////////////////////////////////////////////////////////////////////
                             EVENTS
    //////////////////////////////////////////////////////////////////////////*/

  // Event to demonstrate message sending
  event MessageSent(
    address indexed from,
    address indexed to,
    uint256 amount,
    uint256 messageNonce,
    uint256 gasLimit,
    uint256 expiryTime,
    bytes message
  );

  event DepositMessageCancelled(bytes32 messageHash);

  /*//////////////////////////////////////////////////////////////////////////
                             MESSAGE STRUCTS   
    //////////////////////////////////////////////////////////////////////////*/

  struct DepositMessage {
    address from;
    uint256 nonce;
    uint256 gasLimit;
    uint256 expiryTime;
    bytes message;
    bool isCancelled;
  }

  function sendMessage(address to, uint256 value, bytes memory message, uint256 gasLimit) external payable;

  function sendMessage(
    address to,
    uint256 value,
    bytes calldata message,
    uint256 gasLimit,
    address refundAddress
  ) external payable;
}
