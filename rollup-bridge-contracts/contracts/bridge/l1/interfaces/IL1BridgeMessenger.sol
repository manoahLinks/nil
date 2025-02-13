// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IBridgeMessenger } from "../../interfaces/IBridgeMessenger.sol";

interface IL1BridgeMessenger is IBridgeMessenger {
  /*//////////////////////////////////////////////////////////////////////////
                             EVENTS
    //////////////////////////////////////////////////////////////////////////*/

  // Event to demonstrate message sending
  event MessageSent(
    address indexed from,
    address indexed to,
    uint256 amount,
    uint256 gasLimit,
    address refundAddress,
    address l1TokenAddress,
    address l2TokenAddress,
    uint256 nonce,
    bytes32 messageHash,
    uint256 expiryTime
  );

  /*//////////////////////////////////////////////////////////////////////////
                             MESSAGE STRUCTS   
    //////////////////////////////////////////////////////////////////////////*/

  struct DepositMessage {
    address from;
    address recipient;
    address refundAddress;
    address l1TokenAddress;
    address l2TokenAddress;
    uint256 amount;
    uint256 nonce;
    uint256 gasLimit;
    uint256 expiryTime;
  }
}
