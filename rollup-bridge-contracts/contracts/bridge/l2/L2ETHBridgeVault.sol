// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { NilAccessControlUpgradeable } from "../../NilAccessControlUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { AccessControlEnumerableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import { NilConstants } from "../../common/libraries/NilConstants.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { AddressChecker } from "../../common/libraries/AddressChecker.sol";
import { IL2ETHBridgeVault } from "./interfaces/IL2ETHBridgeVault.sol";

contract L2ETHBridgeVault is
  OwnableUpgradeable,
  PausableUpgradeable,
  NilAccessControlUpgradeable,
  ReentrancyGuardUpgradeable,
  IL2ETHBridgeVault
{
  using AddressChecker for address;

  /*//////////////////////////////////////////////////////////////////////////
                             STATE-VARIABLES   
    //////////////////////////////////////////////////////////////////////////*/

  address public l2EthBridge;

  /// @dev The storage slots for future usage.
  uint256[50] private __gap;

  /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /*//////////////////////////////////////////////////////////////////////////
                                    INITIALIZER
    //////////////////////////////////////////////////////////////////////////*/

  function initialize(address _owner, address _defaultAdmin, address _l2EthBridge) public initializer {
    // Validate input parameters
    if (_owner == address(0)) {
      revert ErrorInvalidOwner();
    }

    if (_defaultAdmin == address(0)) {
      revert ErrorInvalidDefaultAdmin();
    }

    if (!_l2EthBridge.isContract()) {
      revert ErrorInvalidEthBridge();
    }

    // Initialize the Ownable contract with the owner address
    OwnableUpgradeable.__Ownable_init(_owner);

    // Initialize the Pausable contract
    PausableUpgradeable.__Pausable_init();

    // Initialize the AccessControlEnumerable contract
    __AccessControlEnumerable_init();

    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    // Set role admins
    // The OWNER_ROLE is set as its own admin to ensure that only the current owner can manage this role.
    _setRoleAdmin(NilConstants.OWNER_ROLE, NilConstants.OWNER_ROLE);

    // The DEFAULT_ADMIN_ROLE is set as its own admin to ensure that only the current default admin can manage this
    // role.
    _setRoleAdmin(DEFAULT_ADMIN_ROLE, NilConstants.OWNER_ROLE);

    // Grant roles to defaultAdmin and owner
    // The DEFAULT_ADMIN_ROLE is granted to both the default admin and the owner to ensure that both have the
    // highest level of control.
    // The OWNER_ROLE is granted to the owner to ensure they have the highest level of control over the contract.
    _grantRole(NilConstants.OWNER_ROLE, _owner);
    _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);

    l2EthBridge = _l2EthBridge;
  }

  /// @notice Receive function to accept ETH, only callable by the l2EthBridge or Owner
  /// @dev owner of the contract must fund the Vault with ETH
  /// @dev L2EthBridgeVault will transfer ETH to the vault while processing ETH-withdrawal request from user (smart-account)
  /// @dev Either owner or L2EthBridgeVault are allowed to transfer ETH to the vault contract
  receive() external payable {
    if (
      msg.sender != l2EthBridge ||
      hasRole(NilConstants.OWNER_ROLE, msg.sender) ||
      hasRole(DEFAULT_ADMIN_ROLE, msg.sender)
    ) {
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

  /// @inheritdoc IERC165
  function supportsInterface(
    bytes4 interfaceId
  ) public view override(AccessControlEnumerableUpgradeable, IERC165) returns (bool) {
    return interfaceId == type(IL2ETHBridgeVault).interfaceId || super.supportsInterface(interfaceId);
  }
}
