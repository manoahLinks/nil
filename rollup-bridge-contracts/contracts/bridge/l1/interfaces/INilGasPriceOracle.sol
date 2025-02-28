// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface INilGasPriceOracle {
  /// @notice set the maxFeePerGas for nil-chain
  function setMaxFeePerGas(uint256 maxFeePerGas) external;

  /// @notice Return the latest known maxFeePerGas for nil-chain
  function maxFeePerGas() external view returns (uint256);

  /// @notice set the maxPriorityFeePerGas for nil-chain
  function setMaxPriorityFeePerGas(uint256 maxPriorityFeePerGas) external;

  /// @notice Return the latest known maxPriorityFeePerGas for nil-chain
  function maxPriorityFeePerGas() external view returns (uint256);
}
