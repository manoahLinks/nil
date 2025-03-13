// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IBridgeMessenger } from "../../interfaces/IBridgeMessenger.sol";

/// @title IL2BridgeMessenger
/// @notice Interface for the L2BridgeMessenger contract which handles cross-chain messaging between L1 and L2.
/// @dev This interface defines the functions and events for finalizing deposit messages, sending messages to L1, and initiating withdrawals
interface IL2BridgeMessenger is IBridgeMessenger {
  /*//////////////////////////////////////////////////////////////////////////
                             ERRORS
    //////////////////////////////////////////////////////////////////////////*/

  /*//////////////////////////////////////////////////////////////////////////
                             EVENTS
    //////////////////////////////////////////////////////////////////////////*/

  /*//////////////////////////////////////////////////////////////////////////
                             MESSAGE STRUCTS   
    //////////////////////////////////////////////////////////////////////////*/

  /// @notice Enum representing the type of deposit.
  enum DepositType {
    ERC20,
    ETH
  }

  /// @notice Get the list of authorized bridges
  /// @return The list of authorized bridge addresses.
  function getAuthorizedBridges() external view returns (address[] memory);

  /*//////////////////////////////////////////////////////////////////////////
                           PUBLIC MUTATING FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

  /*//////////////////////////////////////////////////////////////////////////
                           RESTRICTED FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

  /// @notice Authorize a bridge addresses
  /// @param bridges The array of addresses of the bridges to authorize.
  function authorizeBridges(address[] memory bridges) external;

  /// @notice Authorize a bridge address
  /// @param bridge The address of the bridge to authorize.
  function authorizeBridge(address bridge) external;

  /// @notice Revoke authorization of a bridge address
  /// @param bridge The address of the bridge to revoke.
  function revokeBridgeAuthorization(address bridge) external;
}
