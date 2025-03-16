// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControlEnumerable } from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { NilConstants } from "../../common/libraries/NilConstants.sol";
import { IL2Bridge } from "./interfaces/IL2Bridge.sol";
import { NilAccessControl } from "../../NilAccessControl.sol";
import { AddressChecker } from "../../common/libraries/AddressChecker.sol";
import { IL2ETHBridge } from "./interfaces/IL2ETHBridge.sol";
import { IL2ETHBridgeVault } from "./interfaces/IL2ETHBridgeVault.sol";

contract L2ETHBridge is ReentrancyGuard, NilAccessControl, Pausable, IL2ETHBridge {
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

  /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

  constructor(
    address _owner,
    address _admin,
    address _counterpartyBridge,
    address _router,
    address _messenger,
    address _l2EthBridgeVault
  ) Ownable(_owner) {
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

    counterpartyBridge = _counterpartyBridge;
    router = _router;
    messenger = _messenger;
    l2ETHBridgeVault = IL2ETHBridgeVault(_l2EthBridgeVault);

    _grantRole(NilConstants.OWNER_ROLE, _owner);
    _grantRole(DEFAULT_ADMIN_ROLE, _admin);
  }

  function finalizeETHDeposit(
    address from,
    address to,
    address feeRefundRecipient,
    uint256 amount,
    bytes memory
  ) public payable {}

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
}
