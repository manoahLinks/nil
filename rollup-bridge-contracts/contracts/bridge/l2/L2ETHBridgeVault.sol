// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControlEnumerable } from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { NilRoleConstants } from "../../libraries/NilRoleConstants.sol";
import { NilAccessControl } from "../../NilAccessControl.sol";
import { AddressChecker } from "../../libraries/AddressChecker.sol";
import { IL2ETHBridgeVault } from "./interfaces/IL2ETHBridgeVault.sol";

contract L2ETHBridgeVault is ReentrancyGuard, NilAccessControl, Pausable, IL2ETHBridgeVault {
  using AddressChecker for address;

  /*//////////////////////////////////////////////////////////////////////////
                             STATE-VARIABLES   
    //////////////////////////////////////////////////////////////////////////*/

  address public l2EthBridge;

  /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

  constructor(address _owner, address _admin, address _l2EthBridge) Ownable(_owner) {
    if (_l2EthBridge.isContract()) {
      revert ErrorInvalidEthBridge();
    }
    l2EthBridge = _l2EthBridge;
    _grantRole(NilRoleConstants.OWNER_ROLE, _owner);
    _grantRole(DEFAULT_ADMIN_ROLE, _admin);
  }

  /// @notice Receive function to accept ETH, only callable by the owner
  receive() external payable {
    if (msg.sender != owner()) {
      revert ErrorUnauthorisedFunding();
    }
  }

  /// @inheritdoc IL2ETHBridgeVault
  function transferETH(address payable recipient, uint256 amount) external nonReentrant {
    if (msg.sender != l2EthBridge) {
      revert ErrorCallerNotL2ETHBridge();
    }

    if (recipient == address(0)) {
      revert ErrorInvalidRecipientAddress();
    }

    if (amount == 0) {
      revert ErrorInvalidTransferAmount();
    }

    if (address(this).balance < amount) {
      revert ErrorInsufficientVaultBalance();
    }

    uint256 initialBalance = address(this).balance;

    (bool success, ) = recipient.call{ value: amount }("");
    require(success, "ETH transfer failed");

    uint256 finalBalance = address(this).balance;
    assert(finalBalance == initialBalance - amount);
  }
}
