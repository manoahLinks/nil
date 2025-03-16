// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IL2Bridge } from "./IL2Bridge.sol";

interface IL2ETHBridge is IL2Bridge {
  /*//////////////////////////////////////////////////////////////////////////
                             ERRORS   
    //////////////////////////////////////////////////////////////////////////*/
  error ErrorInvalidCounterpartyBridge();

  error ErrorInvalidEthBridgeVault();

  /*//////////////////////////////////////////////////////////////////////////
                             EVENTS   
    //////////////////////////////////////////////////////////////////////////*/

  /// @notice Emitted when ETH is deposited from L1 to L2 and transfer to recipient.
  /// @param l2Token The address of the ETH Token in L2.
  /// @param from The address of sender in L1.
  /// @param to The address of recipient in L2.
  /// @param amount The amount of ETH withdrawn from L1 to L2.
  /// @param data The optional calldata passed to recipient in L2.
  event FinalizeDeposit(address indexed l2Token, address indexed from, address to, uint256 amount, bytes data);

  /*//////////////////////////////////////////////////////////////////////////
                             PUBLIC CONSTANT FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

  /*//////////////////////////////////////////////////////////////////////////
                            PUBLIC MUTATION FUNCTIONS      
    //////////////////////////////////////////////////////////////////////////*/

  /// @notice Complete an ETH-deposit from L1 to L2 and send fund to recipient's account in L2.
  /// @dev The function should only be called by L2ScrollMessenger.
  /// @param from The address of account who deposits the ETH in L1.
  /// @param to The address of recipient in L2 to receive the ETH-Token.
  /// @param feeRefundRecipient The address of excess-fee refund recipient on L2.
  /// @param amount The amount of the ETH to deposit.
  /// @param data Optional data to forward to recipient's account.
  function finalizeETHDeposit(
    address from,
    address to,
    address feeRefundRecipient,
    uint256 amount,
    bytes calldata data
  ) external payable;
}
