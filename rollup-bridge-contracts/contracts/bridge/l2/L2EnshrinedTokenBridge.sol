// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IL2EnshrinedTokenBridge } from "./interfaces/IL2EnshrinedTokenBridge.sol";
import { IL2Bridge } from "./interfaces/IL2Bridge.sol";
import { NilConstants } from "../../common/libraries/NilConstants.sol";
import { NilAccessControl } from "../../NilAccessControl.sol";
import { AddressChecker } from "../../common/libraries/AddressChecker.sol";

contract L2EnshrinedTokenBridge is ReentrancyGuard, NilAccessControl, Pausable, IL2EnshrinedTokenBridge {
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

  /***************
   * Constructor *
   ***************/

  /// @notice Constructor for `L2EnshrinedTokenBridge` implementation contract.
  ///
  /// @param _counterpartyBridge The address of `L1ERC20Bridge` contract in L1.
  /// @param _admin The admin address
  /// @param _router The address of `L2BridgeRouter` contract in Nil-Chain.
  /// @param _messenger The address of `L2BridgeMessenger` contract in  Nil-Chain.
  constructor(
    address _owner,
    address _admin,
    address _relayer,
    address _counterpartyBridge,
    address _router,
    address _messenger
  ) Ownable(_owner) {
    if (!_router.isContract()) {
      revert ErrorInvalidRouter();
    }

    if (!_counterpartyBridge.isContract()) {
      revert ErrorInvalidCounterParty();
    }

    if (!_messenger.isContract()) {
      revert ErrorInvalidMessenger();
    }

    counterpartyBridge = _counterpartyBridge;
    router = _router;
    messenger = _messenger;

    // Set role admins
    // The OWNER_ROLE is set as its own admin to ensure that only the current owner can manage this role.
    _setRoleAdmin(NilConstants.OWNER_ROLE, NilConstants.OWNER_ROLE);
    _grantRole(NilConstants.OWNER_ROLE, _owner);

    // The DEFAULT_ADMIN_ROLE is set as its own admin to ensure that only the current default admin can manage this
    // role.
    _setRoleAdmin(DEFAULT_ADMIN_ROLE, NilConstants.OWNER_ROLE);
    _grantRole(DEFAULT_ADMIN_ROLE, _admin);

    _grantRole(NilConstants.RELAYER_ROLE_ADMIN, _admin);
    _grantRole(NilConstants.RELAYER_ROLE_ADMIN, _owner);

    _grantRole(NilConstants.RELAYER_ROLE, _owner);
    _grantRole(NilConstants.RELAYER_ROLE, _admin);
    _grantRole(NilConstants.RELAYER_ROLE, _relayer);
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
}
