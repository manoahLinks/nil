// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IBridgeMessenger } from "../../interfaces/IBridgeMessenger.sol";

interface IL1BridgeMessenger is IBridgeMessenger {
  /*//////////////////////////////////////////////////////////////////////////
                             ERRORS
    //////////////////////////////////////////////////////////////////////////*/

  error DepositMessageAlreadyExist(bytes32 messageHash);

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

  /*//////////////////////////////////////////////////////////////////////////
                             MESSAGE STRUCTS   
    //////////////////////////////////////////////////////////////////////////*/

  struct DepositMessage {
    uint256 nonce;
    uint256 gasLimit;
    uint256 expiryTime;
    bytes message;
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
