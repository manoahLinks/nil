// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IBridgeMessenger } from "./interfaces/IBridgeMessenger.sol";
import { NilAccessControl } from "../NilAccessControl.sol";

abstract contract BaseBridgeMessenger is
    OwnableUpgradeable,
    PausableUpgradeable,
    NilAccessControl,
    ReentrancyGuardUpgradeable,
    IBridgeMessenger
{
    /*//////////////////////////////////////////////////////////////////////////
                             ERRORS   
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Invalid owner address.
    error ErrorInvalidOwner();

    /// @dev Invalid default admin address.
    error ErrorInvalidDefaultAdmin();

    error NotEnoughMessagesInQueue();

    /**
     *
     * Events *
     *
     */

    /// @notice Emitted when owner updates fee vault contract.
    /// @param _oldFeeVault The address of old fee vault contract.
    /// @param _newFeeVault The address of new fee vault contract.
    event UpdateFeeVault(address _oldFeeVault, address _newFeeVault);

    /**
     *
     * Variables *
     *
     */

    /// @notice The address of counterpart BridgeMessenger contract in L1/NilChain.
    address public counterpartMessenger;

    /// @notice The address of fee vault, collecting crosschain messaging fee.
    address public feeVault;

    /// @dev The storage slots for future usage.
    uint256[49] private __gap;

    /**
     *
     * Constructor *
     *
     */
    constructor() { }

    function __BaseBridgeMessenger_init(
        address _owner,
        address _defaultAdmin,
        address _feeVault,
        address _counterpartMessenger
    )
        internal
        onlyInitializing
    {
        // Validate input parameters
        if (_owner == address(0)) {
            revert ErrorInvalidOwner();
        }

        if (_defaultAdmin == address(0)) {
            revert ErrorInvalidDefaultAdmin();
        }

        if (_feeVault != address(0)) {
            feeVault = _feeVault;
        }

        counterpartMessenger = _counterpartMessenger;

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
    }

    // make sure only owner can send ether to messenger to avoid possible user fund loss.
    receive() external payable onlyOwner { }

    /*//////////////////////////////////////////////////////////////////////////
                           PUBLIC CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function computeMessageHash(
        address _sender,
        address _target,
        uint256 _value,
        uint256 _messageNonce,
        bytes memory _message
    )
        public
        pure
        returns (bytes32)
    {
        return keccak256(_encodeCrossChainCalldata(_sender, _target, _value, _messageNonce, _message));
    }

    /*//////////////////////////////////////////////////////////////////////////
                           RESTRICTED FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Update fee vault contract.
    /// @dev This function can only called by contract owner.
    /// @param _newFeeVault The address of new fee vault contract.
    function updateFeeVault(address _newFeeVault) external onlyOwner {
        address _oldFeeVault = feeVault;

        feeVault = _newFeeVault;
        emit UpdateFeeVault(_oldFeeVault, _newFeeVault);
    }

    /// @inheritdoc IBridgeMessenger
    function setPause(bool _status) external onlyOwner {
        if (_status) {
            _pause();
        } else {
            _unpause();
        }
    }

    /// @inheritdoc IBridgeMessenger
    function transferOwnershipRole(address newOwner) external override onlyOwner {
        _revokeRole(OWNER_ROLE, owner());
        super.transferOwnership(newOwner);
        _grantRole(OWNER_ROLE, newOwner);
    }

    /// @dev Internal function to generate the crosschain calldata for a message.
    /// @param _sender Message sender address.
    /// @param _target Target contract address.
    /// @param _value The amount of ETH pass to the target.
    /// @param _messageNonce Nonce for the provided message.
    /// @param _message Message to send to the target.
    /// @return ABI encoded cross domain calldata.
    function _encodeCrossChainCalldata(
        address _sender,
        address _target,
        uint256 _value,
        uint256 _messageNonce,
        bytes memory _message
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSignature(
            "relayMessage(address,address,uint256,uint256,bytes)", _sender, _target, _value, _messageNonce, _message
        );
    }

    /// @dev Internal function to check whether the `_target` address is allowed to avoid attack.
    /// @param _target The address of target address to check.
    function _validateTargetAddress(address _target) internal view {
        // @note check more `_target` address to avoid attack in the future when we add more external contracts.
        require(_target != address(this), "Forbid to call self");
    }
}
