// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IL2EnshrinedTokenBridge } from "./interfaces/IL2EnshrinedTokenBridge.sol";
import { IL2Bridge } from "./interfaces/IL2Bridge.sol";
import { NilRoleConstants } from "../../libraries/NilRoleConstants.sol";
import { NilAccessControl } from "../../NilAccessControl.sol";
import { AddressChecker } from "../../libraries/AddressChecker.sol";

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
  /// @param _router The address of `L2BridgeRouter` contract in Nil-Chain.
  /// @param _messenger The address of `L2BridgeMessenger` contract in  Nil-Chain.
  constructor(address _owner, address _counterpartyBridge, address _router, address _messenger) Ownable(_owner) {
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
    _revokeRole(NilRoleConstants.OWNER_ROLE, owner());
    super.transferOwnership(newOwner);
    _grantRole(NilRoleConstants.OWNER_ROLE, newOwner);
  }
}
