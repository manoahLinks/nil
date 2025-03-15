// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControlEnumerable } from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { NilRoleConstants } from "../../libraries/NilRoleConstants.sol";
import { IL2Bridge } from "./interfaces/IL2Bridge.sol";
import { NilAccessControl } from "../../NilAccessControl.sol";
import { AddressChecker } from "../../libraries/AddressChecker.sol";
import { IL2ETHBridge } from "./interfaces/IL2ETHBridge.sol";
import { IL2ETHBridgeVault } from "./interfaces/IL2ETHBridgeVault.sol";

contract L2ETHBridge is ReentrancyGuard, NilAccessControl, Pausable, IL2ETHBridge {
  using EnumerableSet for EnumerableSet.AddressSet;
  using AddressChecker for address;

  /*//////////////////////////////////////////////////////////////////////////
                             STATE-VARIABLES   
    //////////////////////////////////////////////////////////////////////////*/

  address public counterpartBridge;

  address public messenger;

  IL2ETHBridgeVault public l2ETHBridgeVault;

  /// @notice Mapping from Enshrined-Token-Address from nil-shard to ERC20-Token-Address from L1
  mapping(address => address) public tokenMapping;

  /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

  constructor(
    address _owner,
    address _admin,
    address _counterpartBridge,
    address _messenger,
    address _l2EthBridgeVault
  ) Ownable(_owner) {
    if (!_counterpartBridge.isContract()) {
      revert ErrorInvalidCounterpartyBridge();
    }

    if (!_messenger.isContract()) {
      revert ErrorInvalidMessenger();
    }

    if (_l2EthBridgeVault.isContract()) {
      revert ErrorInvalidEthBridgeVault();
    }

    counterpartBridge = _counterpartBridge;
    messenger = _messenger;
    l2ETHBridgeVault = IL2ETHBridgeVault(_l2EthBridgeVault);

    _grantRole(NilRoleConstants.OWNER_ROLE, _owner);
    _grantRole(DEFAULT_ADMIN_ROLE, _admin);
  }

  function finalizeETHDeposit(
    address from,
    address to,
    address feeRefundRecipient,
    uint256 amount,
    bytes calldata data
  ) external payable {}
}
