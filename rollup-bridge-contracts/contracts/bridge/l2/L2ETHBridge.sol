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
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IL2Bridge } from "./interfaces/IL2Bridge.sol";
import { AddressChecker } from "../../common/libraries/AddressChecker.sol";
import { IL2ETHBridge } from "./interfaces/IL2ETHBridge.sol";
import { IL2ETHBridgeVault } from "./interfaces/IL2ETHBridgeVault.sol";

contract L2ETHBridge is
  OwnableUpgradeable,
  PausableUpgradeable,
  NilAccessControlUpgradeable,
  ReentrancyGuardUpgradeable,
  IL2ETHBridge
{
  using EnumerableSet for EnumerableSet.AddressSet;
  using AddressChecker for address;

  /*//////////////////////////////////////////////////////////////////////////
                             STATE-VARIABLES   
    //////////////////////////////////////////////////////////////////////////*/

  address public override counterpartyBridge;

  address public override messenger;

  address public override router;

  IL2ETHBridgeVault public l2ETHBridgeVault;

  /// @notice Mapping from Enshrined-Token-Address from nil-shard to ERC20-Token-Address from L1
  mapping(address => address) public tokenMapping;

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

  function initialize(
    address _owner,
    address _defaultAdmin,
    address _counterpartyBridge,
    address _router,
    address _messenger,
    address _l2EthBridgeVault
  ) public initializer {
    // Validate input parameters
    if (_owner == address(0)) {
      revert ErrorInvalidOwner();
    }

    if (_defaultAdmin == address(0)) {
      revert ErrorInvalidDefaultAdmin();
    }

    if (!_counterpartyBridge.isContract()) {
      revert ErrorInvalidCounterpartyBridge();
    }

    if (!_messenger.isContract()) {
      revert ErrorInvalidMessenger();
    }

    if (!_router.isContract()) {
      revert ErrorInvalidRouter();
    }

    if (_l2EthBridgeVault.isContract()) {
      revert ErrorInvalidEthBridgeVault();
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

    counterpartyBridge = _counterpartyBridge;
    router = _router;
    messenger = _messenger;
    l2ETHBridgeVault = IL2ETHBridgeVault(_l2EthBridgeVault);
  }

  /*//////////////////////////////////////////////////////////////////////////
                                    MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

  modifier onlyMessenger() {
    // check caller is l2-bridge-messenger
    if (msg.sender != messenger) {
      revert ErrorCallerIsNotMessenger();
    }
    _;
  }

  /*//////////////////////////////////////////////////////////////////////////
                                    PUBLIC MUTATION FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

  function finalizeETHDeposit(
    address from,
    address to,
    address feeRefundRecipient,
    uint256 amount,
    bytes memory
  ) public payable onlyMessenger {}

  /*//////////////////////////////////////////////////////////////////////////
                         RESTRICTED FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IL2Bridge
  function setRouter(address _router) external override onlyOwner {
    router = _router;
  }

  /// @inheritdoc IL2Bridge
  function setMessenger(address _messenger) external override onlyOwner {
    messenger = _messenger;
  }

  /// @inheritdoc IL2Bridge
  function setCounterpartyBridge(address counterpartyBridgeAddress) external override onlyOwner {
    counterpartyBridge = counterpartyBridgeAddress;
  }

  /// @inheritdoc IL2Bridge
  function setPause(bool _status) external override onlyOwner {
    if (_status) {
      _pause();
    } else {
      _unpause();
    }
  }

  /// @inheritdoc IL2Bridge
  function transferOwnershipRole(address newOwner) external override onlyOwner {
    _revokeRole(NilConstants.OWNER_ROLE, owner());
    super.transferOwnership(newOwner);
    _grantRole(NilConstants.OWNER_ROLE, newOwner);
  }

  /// @inheritdoc IERC165
  function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
    return
      interfaceId == type(IL2ETHBridge).interfaceId ||
      interfaceId == type(IL2Bridge).interfaceId ||
      super.supportsInterface(interfaceId);
  }
}
