// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IL1BridgeRouter {
  event L1ERC20BridgeSet(address indexed oldL1ERC20Bridge, address indexed newL1ERC20Bridge);

  event L1BridgeMessengerSet(address indexed oldL1BridgeMessenger, address indexed newL1BridgeMessenger);

  function getL2ERC20Address(address _l1TokenAddress) external view returns (address);

  function getERC20Bridge(address _token) external view returns (address);

  function setL1ERC20Bridge(address _newERC20Bridge) external;

  /// @notice pull ERC20 tokens from users to bridge.
  /// @param sender The address of sender from which the tokens are being pulled.
  /// @param token The address of token to pull.
  /// @param amount The amount of token to be pulled.
  function pullERC20(address sender, address token, uint256 amount) external returns (uint256);

  /**
   * @notice Deposits ERC20 tokens to the nil-chain.
   * @param _token The address of the ERC20 token to deposit.
   * @param _amount The amount of tokens to deposit.
   * @param _gasLimit The gas limit required to complete the deposit on nil-chain.
   */
  function depositERC20(address _token, uint256 _amount, uint256 _gasLimit) external payable;

  /**
   * @notice Initiates the ERC20 tokens to the nil-chain. for a specified recipient.
   * @param _token The address of the ERC20 in L1 token to deposit.
   * @param _to The recipient address to receive the token in nil-chain.
   * @param _amount The amount of tokens to deposit.
   * @param _gasLimit The gas limit required to complete the deposit on nil-chain..
   */
  function depositERC20(address _token, address _to, uint256 _amount, uint256 _gasLimit) external payable;

  /**
   * @notice Deposits ERC20 tokens to the nil-chain for a specified recipient and calls a function on the recipient's
   * contract.
   * @param _token The address of the ERC20 in L1 token to deposit.
   * @param _to The recipient address to receive the token in nil-chain.
   * @param _amount The amount of tokens to deposit.
   * @param _data Optional data to forward to the recipient's account.
   * @param _gasLimit The gas limit required to complete the deposit on nil-chain.
   */
  function depositERC20AndCall(
    address _token,
    address _to,
    uint256 _amount,
    bytes memory _data,
    uint256 _gasLimit
  ) external payable;

  /**
   * @notice Pauses or unpauses the contract.
   * @dev This function allows the owner to pause or unpause the contract.
   * @param _status The pause status to update.
   */
  function setPause(bool _status) external;

  /**
   * @notice transfers ownership to the newOwner.
   * @dev This function revokes the `OWNER_ROLE` from the current owner, calls `acceptOwnership` using
   * OwnableUpgradeable's `transferOwnership` transfer the owner rights to newOwner
   * @param newOwner The address of the new owner.
   */
  function transferOwnershipRole(address newOwner) external;
}
