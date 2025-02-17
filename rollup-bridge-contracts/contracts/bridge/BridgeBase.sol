// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IBridge } from "./interfaces/IBridge.sol";
import { IBridgeMessenger } from "./interfaces/IBridgeMessenger.sol";

/// @title BridgeBase
/// @notice The `BridgeBase` is a base contract for Bridge contracts used in both in L1 and L2.
abstract contract BridgeBase is ReentrancyGuardUpgradeable, OwnableUpgradeable, IBridge {
    /// @inheritdoc IBridge
    address public override router;

    /// @inheritdoc IBridge
    address public override counterpartyBridge;

    /// @inheritdoc IBridge
    address public override messenger;

    /// @dev The storage slots for future usage.
    uint256[50] private __gap;

    constructor() { }

    function _initialize(address _owner, address _counterpartyBridge, address _messenger) internal {
        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
        OwnableUpgradeable.__Ownable_init(_owner);
        counterpartyBridge = _counterpartyBridge;
        messenger = _messenger;
    }
}
