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
import { IL2EnshrinedTokenBridge } from "./interfaces/IL2EnshrinedTokenBridge.sol";
import { IL2Bridge } from "./interfaces/IL2Bridge.sol";
import { AddressChecker } from "../../common/libraries/AddressChecker.sol";

contract L2EnshrinedTokenBridge is
  OwnableUpgradeable,
  PausableUpgradeable,
  NilAccessControlUpgradeable,
  ReentrancyGuardUpgradeable,
  IL2EnshrinedTokenBridge
{
  using AddressChecker for address;

  /*************
   * Variables *
   *************/

  /// @notice address of the counterparty Bridge (L1ERC20Bridge)
  address public override counterpartyBridge;

  /// @notice address of the L2BridgeRouter
  address public override router;

  /// @notice address of the L2BridgeMessenger
  address public override messenger;

  /// @notice Mapping from enshrined-token-address to layer-1 ERC20-TokenAddress.
  // solhint-disable-next-line var-name-mixedcase
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

  /// @notice initialize function for `L2EnshrinedTokenBridge` implementation contract.
  /// @param _counterpartyBridge The address of `L1ERC20Bridge` contract in L1.
  /// @param _defaultAdmin The admin address
  /// @param _router The address of `L2BridgeRouter` contract in Nil-Chain.
  /// @param _messenger The address of `L2BridgeMessenger` contract in  Nil-Chain.

  function initialize(
    address _owner,
    address _defaultAdmin,
    address _counterpartyBridge,
    address _router,
    address _messenger
  ) public initializer {
    // Validate input parameters
    if (_owner == address(0)) {
      revert ErrorInvalidOwner();
    }

    if (_defaultAdmin == address(0)) {
      revert ErrorInvalidDefaultAdmin();
    }

    // TODO check on the supportsInterface validation for IL2BridgeRouter

    if (!_router.isContract()) {
      revert ErrorInvalidRouter();
    }

    // TODO check on the supportsInterface validation for IL1ERC20Bridge

    if (!_counterpartyBridge.isContract()) {
      revert ErrorInvalidCounterParty();
    }

    // TODO check on the supportsInterface validation for IL2BridgeMessenger

    if (!_messenger.isContract()) {
      revert ErrorInvalidMessenger();
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
  }

  /*//////////////////////////////////////////////////////////////////////////
                             FUNCTION MODIFIERS   
    //////////////////////////////////////////////////////////////////////////*/

  modifier onlyMessenger() {
    // check caller is l2-bridge-messenger
    if (msg.sender != messenger) {
      revert ErrorCallerIsNotMessenger();
    }
    _;
  }

  /*//////////////////////////////////////////////////////////////////////////
                             PUBLIC CONSTANT FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

  function getL1ERC20Address(address l2Token) external view override returns (address) {
    return tokenMapping[l2Token];
  }

  /*//////////////////////////////////////////////////////////////////////////
                             PUBLIC MUTATING FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

  function finalizeERC20Deposit(
    address l1Token,
    address l2Token,
    address depositor,
    address recipient,
    address feeRefundRecipient,
    uint256 depositAmount,
    bytes calldata targetCallData
  ) external payable override onlyMessenger nonReentrant {
    if (l1Token.isContract()) {
      revert ErrorInvalidL1TokenAddress();
    }

    // TODO - check if the l1TokenAddress is a contract address
    // TODO - check if the l2TokenAddress exists and is a contract
    // TODO - if the L1Token address mapping doesnot exist, it means the L2Token is to be created
    // TODO - Mapping for L1TokenAddress to be set

    if (l1Token != tokenMapping[l2Token]) {
      revert ErrorL1TokenAddressMismatch();
    }

    // TODO - Mint EnshrinedToken Amount to recipient

    // TODO - assert that the balance increase on the recipient is equal to the depositAmount

    emit FinalizeDepositERC20(
      l1Token,
      l2Token,
      depositor,
      recipient,
      feeRefundRecipient,
      depositAmount,
      targetCallData
    );
  }

  /*//////////////////////////////////////////////////////////////////////////
                         RESTRICTED FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IL2Bridge
  function setRouter(address routerAddress) external override onlyOwner {
    router = routerAddress;
  }

  /// @inheritdoc IL2Bridge
  function setMessenger(address messengerAddress) external override onlyOwner {
    messenger = messengerAddress;
  }

  /// @inheritdoc IL2Bridge
  function setCounterpartyBridge(address counterpartyBridgeAddress) external override onlyOwner {
    counterpartyBridge = counterpartyBridgeAddress;
  }

  function setTokenMapping(address l2EnshrinedTokenAddress, address l1TokenAddress) external override onlyOwner {
    if (l2EnshrinedTokenAddress == address(0) || l1TokenAddress == address(0)) {
      revert ErrorInvalidTokenAddress();
    }

    // TODO - check if the tokenAddresses are not EOA and a valid contract
    // TODO - check if the l2EnshrinedTokenAddress implement ERC-165 or any common interface

    tokenMapping[l2EnshrinedTokenAddress] = l1TokenAddress;

    emit TokenMappingUpdated(l2EnshrinedTokenAddress, l1TokenAddress);
  }

  /// @inheritdoc IL2EnshrinedTokenBridge
  function setPause(bool _status) external override onlyOwner {
    if (_status) {
      _pause();
    } else {
      _unpause();
    }
  }

  /// @inheritdoc IL2EnshrinedTokenBridge
  function transferOwnershipRole(address newOwner) external override onlyOwner {
    _revokeRole(NilConstants.OWNER_ROLE, owner());
    super.transferOwnership(newOwner);
    _grantRole(NilConstants.OWNER_ROLE, newOwner);
  }

  /// @inheritdoc IERC165
  function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
    return
      interfaceId == type(IL2EnshrinedTokenBridge).interfaceId ||
      interfaceId == type(IL2Bridge).interfaceId ||
      super.supportsInterface(interfaceId);
  }
}
