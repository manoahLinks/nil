// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IL2ETHBridgeVault {
  error ErrorInvalidEthBridge();
  error ErrorCallerNotL2ETHBridge();
  error ErrorInvalidRecipientAddress();
  error ErrorInvalidTransferAmount();
  error ErrorInsufficientVaultBalance();
  error ErrorUnauthorisedFunding();

  /// @notice Transfers ETH to a recipient, only callable by the L2ETHBridge contract
  /// @param recipient The address of the recipient
  /// @param amount The amount of ETH to transfer
  function transferETH(address payable recipient, uint256 amount) external;
}
