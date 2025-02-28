// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IL1BridgeRouter {
  event L1ERC20BridgeSet(address indexed oldL1ERC20Bridge, address indexed newL1ERC20Bridge);

  event L1ETHBridgeSet(address indexed oldL1ETHBridge, address indexed newL1ETHBridge);

  event L1BridgeMessengerSet(address indexed oldL1BridgeMessenger, address indexed newL1BridgeMessenger);

  function getL2ERC20Address(address l1TokenAddress) external view returns (address);

  function getERC20Bridge(address token) external view returns (address);

  function l1ETHBridge() external view returns (address);

  function setL1ERC20Bridge(address newERC20Bridge) external;

  function setL1ETHBridge(address newL1ETHBridge) external;

  /// @notice pull ERC20 tokens from users to bridge.
  /// @param sender The address of sender from which the tokens are being pulled.
  /// @param token The address of token to pull.
  /// @param amount The amount of token to be pulled.
  function pullERC20(address sender, address token, uint256 amount) external returns (uint256);

  /**
   * @notice Initiates the ERC20 tokens to the nil-chain. for a specified recipient.
   * @param token The address of the ERC20 in L1 token to deposit.
   * @param to The recipient address to receive the token in nil-chain.
   * @param amount The amount of tokens to deposit.
   * @param l2FeeRefundRecipient The recipient address to recieve the excess fee refund on nil-chain
   * @param gasLimit The gas limit required to complete the deposit on nil-chain.
   */
  function depositERC20(
    address token,
    address to,
    uint256 amount,
    address l2FeeRefundRecipient,
    uint256 gasLimit
  ) external payable;

  /**
   * @notice Deposits ERC20 tokens to the nil-chain for a specified recipient and calls a function on the recipient's
   * contract.
   * @param token The address of the ERC20 in L1 token to deposit.
   * @param to The recipient address to receive the token in nil-chain.
   * @param amount The amount of tokens to deposit.
   * @param l2FeeRefundRecipient The recipient address to recieve the excess fee refund on nil-chain
   * @param data Optional data to forward to the recipient's account.
   * @param gasLimit The gas limit required to complete the deposit on nil-chain.
   */
  function depositERC20AndCall(
    address token,
    address to,
    uint256 amount,
    address l2FeeRefundRecipient,
    bytes memory data,
    uint256 gasLimit
  ) external payable;

  /**
   * @notice Initiates the ETH to the nil-chain. for a specified recipient.
   * @param to The recipient address to receive the token in nil-chain.
   * @param amount The amount of ETH to deposit.
   * @param l2FeeRefundRecipient The recipient address for excess-fee refund on nil-chain
   * @param gasLimit The gas limit required to complete the deposit on nil-chain..
   */
  function depositETH(address to, uint256 amount, address l2FeeRefundRecipient, uint256 gasLimit) external payable;

  /**
   * @notice Deposits ETH to the nil-chain for a specified recipient and calls a function on the recipient's
   * contract.
   * @param to The recipient address to receive the ETH in nil-chain.
   * @param amount The amount of ETH to deposit.
   * @param l2FeeRefundRecipient The recipient address for excess-fee refund on nil-chain
   * @param data Optional data to forward to the recipient's account.
   * @param gasLimit The gas limit required to complete the deposit on nil-chain.
   */
  function depositETHAndCall(
    address to,
    uint256 amount,
    address l2FeeRefundRecipient,
    bytes memory data,
    uint256 gasLimit
  ) external payable;

  /**
   * @notice Pauses or unpauses the contract.
   * @dev This function allows the owner to pause or unpause the contract.
   * @param statusValue The pause status to update.
   */
  function setPause(bool statusValue) external;

  /**
   * @notice transfers ownership to the newOwner.
   * @dev This function revokes the `OWNER_ROLE` from the current owner, calls `acceptOwnership` using
   * OwnableUpgradeable's `transferOwnership` transfer the owner rights to newOwner
   * @param newOwner The address of the new owner.
   */
  function transferOwnershipRole(address newOwner) external;
}
