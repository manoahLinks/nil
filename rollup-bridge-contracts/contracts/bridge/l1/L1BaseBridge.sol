// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IL1Bridge } from "./interfaces/IL1Bridge.sol";
import { IBridge } from "../interfaces/IBridge.sol";
import { NilAccessControl } from "../../NilAccessControl.sol";

abstract contract L1BaseBridge is
  OwnableUpgradeable,
  PausableUpgradeable,
  NilAccessControl,
  ReentrancyGuardUpgradeable,
  IL1Bridge
{
  /*//////////////////////////////////////////////////////////////////////////
                             ERRORS   
    //////////////////////////////////////////////////////////////////////////*/

  /// @dev Invalid owner address.
  error ErrorInvalidOwner();

  /// @dev Invalid default admin address.
  error ErrorInvalidDefaultAdmin();

  /// @dev Invalid counterparty WETH bridge address.
  error ErrorInvalidCounterpartyBridge();

  /// @dev Invalid messenger address.
  error ErrorInvalidMessenger();

  /// @dev Invalid nil gas price oracle address.
  error ErrorInvalidNilGasPriceOracle();

  error ErrorInvalidL2DepositRecipient();

  error ErrorInvalidL2FeeRefundRecipient();

  error ErrorInvalidNilGasLimit();

  /// @dev Insufficient value for fee credit.
  error ErrorInsufficientValueForFeeCredit();

  /// @dev Empty deposit.
  error ErrorEmptyDeposit();

  /*//////////////////////////////////////////////////////////////////////////
                             STATE-VARIABLES   
    //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IL1Bridge
  address public override router;

  /// @inheritdoc IL1Bridge
  address public override counterpartyBridge;

  /// @inheritdoc IL1Bridge
  address public override messenger;

  /// @inheritdoc IL1Bridge
  address public override nilGasPriceOracle;

  /// @dev The storage slots for future usage.
  uint256[50] private __gap;

  /*//////////////////////////////////////////////////////////////////////////
                             CONSTRUCTOR  
    //////////////////////////////////////////////////////////////////////////*/
  constructor() {}

  /*//////////////////////////////////////////////////////////////////////////
                             INITIALISER  
    //////////////////////////////////////////////////////////////////////////*/

  function __L1BaseBridge_init(
    address _owner,
    address _defaultAdmin,
    address _counterPartyBridge,
    address _messenger,
    address _nilGasPriceOracle
  ) internal onlyInitializing {
    // Validate input parameters
    if (_owner == address(0)) {
      revert ErrorInvalidOwner();
    }

    if (_defaultAdmin == address(0)) {
      revert ErrorInvalidDefaultAdmin();
    }

    // TODO - check if _counterPartyBridge implements IERC165, IBridge interface
    if (_counterPartyBridge == address(0)) {
      revert ErrorInvalidCounterpartyBridge();
    }

    // TODO - check if counterpartyMessener implements IERC165, IBridgeMessenger interface
    if (_messenger == address(0)) {
      revert ErrorInvalidMessenger();
    }

    // TODO - check if the _nilGasPriceOracle implements IERC165 interface
    if (_nilGasPriceOracle == address(0)) {
      revert ErrorInvalidNilGasPriceOracle();
    }

    // Initialize the Ownable contract with the owner address
    OwnableUpgradeable.__Ownable_init(_owner);

    // Initialize the Pausable contract
    PausableUpgradeable.__Pausable_init();

    // Initialize the AccessControlEnumerable contract
    __AccessControlEnumerable_init();

    // Set role admins
    // The OWNER_ROLE is set as its own admin to ensure that only the current owner can manage this role.
    _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);

    // The DEFAULT_ADMIN_ROLE is set as its own admin to ensure that only the current default admin can manage this
    // role.
    _setRoleAdmin(DEFAULT_ADMIN_ROLE, OWNER_ROLE);

    // Grant roles to defaultAdmin and owner
    // The DEFAULT_ADMIN_ROLE is granted to both the default admin and the owner to ensure that both have the
    // highest level of control.
    // The PROPOSER_ROLE_ADMIN is granted to both the default admin and the owner to allow them to manage proposers.
    // The OWNER_ROLE is granted to the owner to ensure they have the highest level of control over the contract.
    _grantRole(OWNER_ROLE, _owner);
    _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);

    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    counterpartyBridge = _counterPartyBridge;
    messenger = _messenger;
    nilGasPriceOracle = _nilGasPriceOracle;
  }

  /// @inheritdoc IL1Bridge
  function setRouter(address _router) external override onlyOwner {
    router = _router;
  }

  /// @inheritdoc IL1Bridge
  function setMessenger(address _messenger) external override onlyOwner {
    messenger = _messenger;
  }

  /// @inheritdoc IL1Bridge
  function setNilGasPriceOracle(address _nilGasPriceOracle) external override onlyAdmin {
    nilGasPriceOracle = _nilGasPriceOracle;
  }

  /*//////////////////////////////////////////////////////////////////////////
                             RESTRICTED FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IBridge
  function setPause(bool _status) external onlyOwner {
    if (_status) {
      _pause();
    } else {
      _unpause();
    }
  }

  /// @inheritdoc IBridge
  function transferOwnershipRole(address newOwner) external override onlyOwner {
    _revokeRole(OWNER_ROLE, owner());
    super.transferOwnership(newOwner);
    _grantRole(OWNER_ROLE, newOwner);
  }

  /// @inheritdoc IERC165
  function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
    return interfaceId == type(IL1Bridge).interfaceId || interfaceId == type(IERC165).interfaceId;
  }
}
