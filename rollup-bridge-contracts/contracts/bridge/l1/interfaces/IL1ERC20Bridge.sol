// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IL1Bridge } from "./IL1Bridge.sol";

interface IL1ERC20Bridge is IL1Bridge {
  /*//////////////////////////////////////////////////////////////////////////
                             ERRORS   
    //////////////////////////////////////////////////////////////////////////*/

  /// @dev Invalid owner address.
  error ErrorInvalidOwner();

  /// @dev Invalid default admin address.
  error ErrorInvalidDefaultAdmin();

  error ErrorInvalidTokenAddress();

  error ErrorWETHTokenNotSupportedOnERC20Bridge();

  error ErrorInvalidL2DepositRecipient();

  error ErrorInvalidL2FeeRefundRecipient();

  error ErrorInvalidNilGasLimit();

  error ErrorInsufficientValueForFeeCredit();

  error ErrorInvalidL2Token();

  error ErrorEmptyDeposit();

  error ErrorTokenNotSupported();

  error ErrorIncorrectAmountPulledByBridge();

  error ErrorInvalidCounterpartyERC20Bridge();

  error ErrorInvalidWethToken();

  error ErrorInvalidMessenger();

  error ErrorInvalidNilGasPriceOracle();

  /*//////////////////////////////////////////////////////////////////////////
                             EVENTS   
    //////////////////////////////////////////////////////////////////////////*/

  /// @notice Emitted when token mapping for ERC20 token is updated.
  /// @param l1Token The address of ERC20 token in layer-1.
  /// @param oldL2Token The address of the old ERC20Token-Address in nil-chain.
  /// @param newL2Token The address of the new ERC20Token-Address in nil-chain.
  event UpdateTokenMapping(address indexed l1Token, address indexed oldL2Token, address indexed newL2Token);

  /// @notice Emitted upon deposit of ERC20Token from layer-1 to nil-chain.
  /// @param l1Token The address of the token in layer-1.
  /// @param l2Token The address of the token in nil-chain.
  /// @param from The address of sender in layer-1.
  /// @param to The address of recipient in nil-chain.
  /// @param amount The amount of token will be deposited from layer-1 to nil-chain.
  /// @param data The optional calldata passed to recipient in nil-chain.
  event DepositERC20(address indexed l1Token, address indexed l2Token, address indexed from, address to, uint256 amount, bytes data);

  event DepositCancelled(bytes32 indexed messageHash, address indexed l1Token, address indexed cancelledDepositRecipient, uint256 amount);

  /*//////////////////////////////////////////////////////////////////////////
                             PUBLIC CONSTANT FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

  function getL2TokenAddress(address l1TokenAddress) external view returns (address);

  function wethToken() external view returns (address);

  /*//////////////////////////////////////////////////////////////////////////
                             PUBLIC MUTATING FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

  /**
   * @notice Initiates the ERC20 tokens to the nil-chain. for a specified recipient.
   * @param token The address of the ERC20 in L1 token to deposit.
   * @param to The recipient address to receive the token in nil-chain.
   * @param amount The amount of tokens to deposit.
   * @param l2FeeRefundRecipient The recipient address to receive the refund of excess fee on nil-chain
   * @param gasLimit The gas limit required to complete the deposit on nil-chain..
   */
  function depositERC20(
    address token,
    address to,
    uint256 amount,
    address l2FeeRefundRecipient,
    uint256 gasLimit,
    uint256 userFeePerGas,
    uint256 userMaxFeePerGas
  ) external payable;

  /**
   * @notice Deposits ERC20 tokens to the nil-chain for a specified recipient and calls a function on the recipient's
   * contract.
   * @param token The address of the ERC20 in L1 token to deposit.
   * @param to The recipient address to receive the token in nil-chain.
   * @param amount The amount of tokens to deposit.
   * @param l2FeeRefundRecipient The recipient address to receive the refund of excess fee on nil-chain
   * @param data Optional data to forward to the recipient's account.
   * @param gasLimit The gas limit required to complete the deposit on nil-chain.
   */
  function depositERC20AndCall(
    address token,
    address to,
    uint256 amount,
    address l2FeeRefundRecipient,
    bytes memory data,
    uint256 gasLimit,
    uint256 userFeePerGas,
    uint256 userMaxFeePerGas
  ) external payable;
}
