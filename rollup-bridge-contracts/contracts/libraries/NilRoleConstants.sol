// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title NilRoleConstants
/// @notice Contains role constants for access control.
library NilRoleConstants {
  bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
  bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
  bytes32 public constant PROPOSER_ROLE_ADMIN = keccak256("PROPOSER_ROLE_ADMIN");
  bytes32 public constant GAS_PRICE_SETTER_ROLE = keccak256("GAS_PRICE_SETTER_ROLE");
  bytes32 public constant GAS_PRICE_SETTER_ROLE_ADMIN = keccak256("GAS_PRICE_SETTER_ROLE_ADMIN");
}
