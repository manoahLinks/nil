// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IL1ERC20Bridge } from "./IL1ERC20Bridge.sol";

interface IL1BridgeRouter is IL1ERC20Bridge {
  event L1ERC20BridgeSet(address indexed oldL1ERC20Bridge, address indexed newL1ERC20Bridge);
  event L1BridgeMessengerSet(address indexed oldL1BridgeMessenger, address indexed newL1BridgeMessenger);

  function getL2ERC20Address(address _l1TokenAddress) external view override returns (address);

  function getERC20Bridge(address _token) external view returns (address);

  function setL1ERC20Bridge(address _newERC20Bridge) external;

  /// @notice pull ERC20 tokens from users to bridge.
  /// @param sender The address of sender from which the tokens are being pulled.
  /// @param token The address of token to pull.
  /// @param amount The amount of token to be pulled.
  function pullERC20(address sender, address token, uint256 amount) external returns (uint256);
}
