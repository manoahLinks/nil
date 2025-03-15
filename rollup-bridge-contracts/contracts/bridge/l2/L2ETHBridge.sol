// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IL2ETHBridge } from "./interfaces/IL2ETHBridge.sol";

contract L2ETHBridge is IL2ETHBridge {
  function finalizeETHDeposit(
    address from,
    address to,
    address feeRefundRecipient,
    uint256 amount,
    bytes calldata data
  ) external payable {}
}
