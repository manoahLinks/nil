// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IL1Bridge } from "./IL1Bridge.sol";

interface IL1ETHBridge is IL1Bridge {
  /// @notice Emitted upon deposit of ETH from layer-1 to nil-chain.
  /// @param l2Token The address of the token in nil-chain.
  /// @param depositor The address of sender in layer-1.
  /// @param l2Recipient The address of recipient in nil-chain.
  /// @param amount The amount of token will be deposited from layer-1 to nil-chain.
  /// @param data The optional calldata passed to recipient in nil-chain.
  event DepositETH(address indexed l2Token, address indexed depositor, address l2Recipient, uint256 amount, bytes data);

  event DepositCancelled(bytes32 indexed messageHash, address indexed cancelledDepositRecipient, uint256 amount);

  /*//////////////////////////////////////////////////////////////////////////
                             PUBLIC CONSTANT FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

  function l2EthAddress() external view returns (address);

  /*//////////////////////////////////////////////////////////////////////////
                             PUBLIC MUTATING FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

  /**
   * @notice Initiates the ETH to the nil-chain. for a specified recipient.
   * @param l2Recipient The recipient address to receive the token in nil-chain.
   * @param amount The amount of ETH to deposit.
   * @param l2FeeRefundRecipient The recipient address for excess-fee refund on nil-chain
   * @param gasLimit The gas limit required to complete the deposit on nil-chain..
   */
  function depositETH(
    address l2Recipient,
    uint256 amount,
    address l2FeeRefundRecipient,
    uint256 gasLimit,
    uint256 userFeePerGas,
    uint256 userMaxFeePerGas
  ) external payable;

  /**
   * @notice Deposits ETH to the nil-chain for a specified recipient and calls a function on the recipient's
   * contract.
   * @param l2Recipient The recipient address to receive the ETH in nil-chain.
   * @param amount The amount of ETH to deposit.
   * @param l2FeeRefundRecipient The recipient address for excess-fee refund on nil-chain
   * @param data Optional data to forward to the recipient's account.
   * @param gasLimit The gas limit required to complete the deposit on nil-chain.
   */
  function depositETHAndCall(
    address l2Recipient,
    uint256 amount,
    address l2FeeRefundRecipient,
    bytes memory data,
    uint256 gasLimit,
    uint256 userFeePerGas,
    uint256 userMaxFeePerGas
  ) external payable;
}
