// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IL1BridgeMessenger } from "./interfaces/IL1BridgeMessenger.sol";
import { IL1Bridge } from "./interfaces/IL1Bridge.sol";
import { NilAccessControl } from "../../NilAccessControl.sol";
import { Queue } from "../libraries/Queue.sol";

contract L1BridgeMessenger is
    OwnableUpgradeable,
    PausableUpgradeable,
    NilAccessControl,
    ReentrancyGuardUpgradeable,
    IL1BridgeMessenger
{
    using Queue for Queue.QueueData;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////////////////
                             ERRORS   
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Invalid owner address.
    error ErrorInvalidOwner();

    /// @dev Invalid default admin address.
    error ErrorInvalidDefaultAdmin();

    error NotEnoughMessagesInQueue();

    /*//////////////////////////////////////////////////////////////////////////
                             STATE-VARIABLES   
    //////////////////////////////////////////////////////////////////////////*/

    // Add this mapping to store deposit messages by their message hash
    mapping(bytes32 => DepositMessage) public depositMessages;

    /// @notice The nonce for deposit messages.
    uint256 public depositNonce;

    /// @notice Queue to store message hashes
    Queue.QueueData private messageQueue;

    uint256 public maxProcessingTime;

    uint256 public cancelTimeDelta;

    EnumerableSet.AddressSet private authorizedBridges;

    address private l1NilRollup;

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
        address _l1NilRollup,
        uint256 _maxProcessingTime,
        uint256 _cancelTimeDelta
    )
        public
        initializer
    {
        // Validate input parameters
        if (_owner == address(0)) {
            revert ErrorInvalidOwner();
        }

        if (_defaultAdmin == address(0)) {
            revert ErrorInvalidDefaultAdmin();
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
        depositNonce = 0;

        if (_maxProcessingTime == 0) {
            revert InvalidMaxMessageProcessingTime();
        }
        maxProcessingTime = _maxProcessingTime;

        if (_cancelTimeDelta == 0) {
            revert InvalidMessageCancelDeltaTime();
        }
        cancelTimeDelta = _cancelTimeDelta;
        l1NilRollup = _l1NilRollup;
    }

    // make sure only owner can send ether to messenger to avoid possible user fund loss.
    receive() external payable onlyOwner { }

    /*//////////////////////////////////////////////////////////////////////////
                             MODIFIERS  
    //////////////////////////////////////////////////////////////////////////*/

    modifier onlyAuthorizedL1Bridge() {
        if (!authorizedBridges.contains(msg.sender)) {
            revert BridgeNotAuthorized();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                             PUBLIC CONSTANT FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IL1BridgeMessenger
    function getCurrentDepositNonce() public view returns (uint256) {
        return depositNonce;
    }

    /// @inheritdoc IL1BridgeMessenger
    function getNextDepositNonce() public view returns (uint256) {
        return depositNonce + 1;
    }

    /// @inheritdoc IL1BridgeMessenger
    function getDepositType(bytes32 msgHash) public view returns (DepositType depositType) {
        return depositMessages[msgHash].depositType;
    }

    /// @inheritdoc IL1BridgeMessenger
    function getDepositMessage(bytes32 msgHash) public view returns (DepositMessage memory depositMessage) {
        return depositMessages[msgHash];
    }

    /// @inheritdoc IL1BridgeMessenger
    function getAuthorizedBridges() external view returns (address[] memory) {
        return authorizedBridges.values();
    }

    /*//////////////////////////////////////////////////////////////////////////
                             RESTRICTED FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IL1BridgeMessenger
    function authorizeBridges(address[] calldata bridges) external onlyOwner {
        for (uint256 i = 0; i < bridges.length; i++) {
            _authorizeBridge(bridges[i]);
        }
    }

    /// @inheritdoc IL1BridgeMessenger
    function authorizeBridge(address bridge) external override onlyOwner {
        _authorizeBridge(bridge);
    }

    function _authorizeBridge(address bridge) internal {
        if (!IERC165(bridge).supportsInterface(type(IL1Bridge).interfaceId)) {
            revert InvalidBridgeInterface();
        }
        if (authorizedBridges.contains(bridge)) {
            revert BridgeAlreadyAuthorized();
        }
        authorizedBridges.add(bridge);
    }

    /// @inheritdoc IL1BridgeMessenger
    function revokeBridgeAuthorization(address bridge) external override onlyOwner {
        if (!authorizedBridges.contains(bridge)) {
            revert BridgeNotAuthorized();
        }
        authorizedBridges.remove(bridge);
    }

    /*//////////////////////////////////////////////////////////////////////////
                             PUBLIC MUTATING FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IL1BridgeMessenger
    function sendMessage(
        DepositType depositType,
        address to,
        uint256 value,
        bytes memory message,
        uint256 gasLimit
    )
        external
        payable
        override
        whenNotPaused
        onlyAuthorizedL1Bridge
    {
        _sendMessage(depositType, to, value, message, gasLimit, _msgSender());
    }

    /// @inheritdoc IL1BridgeMessenger
    function sendMessage(
        DepositType depositType,
        address to,
        uint256 value,
        bytes calldata message,
        uint256 gasLimit,
        address refundAddress
    )
        external
        payable
        override
        whenNotPaused
        onlyAuthorizedL1Bridge
    {
        _sendMessage(depositType, to, value, message, gasLimit, refundAddress);
    }

    /// @inheritdoc IL1BridgeMessenger
    function cancelDeposit(bytes32 messageHash) public override whenNotPaused onlyAuthorizedL1Bridge {
        // Check if the deposit message exists
        DepositMessage storage depositMessage = depositMessages[messageHash];
        if (depositMessage.expiryTime == 0) {
            revert DepositMessageDoesNotExist(messageHash);
        }

        // Check if the deposit message is already canceled
        if (depositMessage.isCancelled) {
            revert DepositMessageAlreadyCancelled(messageHash);
        }

        // Check if the message hash is in the queue
        if (!messageQueue.contains(messageHash)) {
            revert MessageHashNotInQueue(messageHash);
        }

        // Calculate the expiration time with delta
        uint256 expirationTimeWithDelta = depositMessage.expiryTime + cancelTimeDelta;

        // Check if the current time is greater than the expiration time with delta
        if (block.timestamp <= expirationTimeWithDelta) {
            revert DepositMessageNotExpired(messageHash);
        }

        // Mark the deposit message as canceled
        depositMessage.isCancelled = true;

        // Remove the message hash from the queue
        messageQueue.popFront();

        // Emit an event for the cancellation
        emit DepositMessageCancelled(messageHash);
    }

    /// @inheritdoc IL1BridgeMessenger
    function popMessages(uint256 messageCount) external override returns (bytes32[] memory) {
        if (_msgSender() != l1NilRollup) {
            revert NotAuthorizedToPopMessages();
        }

        // Check queue size and revert if messageCount > queue size
        uint256 queueSize = messageQueue.getSize();
        if (messageCount > queueSize) {
            revert NotEnoughMessagesInQueue();
        }

        // check queue Size and revert if the messageCount > QueueSize
        // Pop messages from the queue
        bytes32[] memory poppedMessages = messageQueue.popFrontBatch(messageCount);
        return poppedMessages;
    }

    /*//////////////////////////////////////////////////////////////////////////
                             INTERNAL FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

    function _sendMessage(
        DepositType _depositType,
        address _to,
        uint256 _amount,
        bytes memory _message,
        uint256 _gasLimit,
        address _refundAddress
    )
        internal
        nonReentrant
    {
        DepositMessage memory depositMessage = DepositMessage({
            sender: _msgSender(),
            nonce: depositNonce,
            gasLimit: _gasLimit,
            expiryTime: block.timestamp + maxProcessingTime,
            message: _message,
            isCancelled: false,
            refundAddress: _refundAddress,
            depositType: _depositType
        });

        bytes32 messageHash = _computeMessageHash(_to, _amount, depositMessage);

        if (depositMessages[messageHash].expiryTime > 0) {
            revert DepositMessageAlreadyExist(messageHash);
        }

        depositMessages[messageHash] = depositMessage;

        messageQueue.pushBack(messageHash);

        emit MessageSent(
            messageHash,
            _msgSender(),
            _to,
            _depositType,
            _amount,
            depositMessage.nonce,
            depositMessage.expiryTime,
            depositMessage.gasLimit,
            _message
        );

        depositNonce++;
    }

    function _computeMessageHash(
        address _to,
        uint256 _amount,
        DepositMessage memory _depositMessage
    )
        public
        view
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(_msgSender(), _to, _amount, _depositMessage.nonce, _depositMessage.message));
    }

    /// @dev Internal function to check whether the `_target` address is allowed to avoid attack.
    /// @param _target The address of target address to check.
    function _validateTargetAddress(address _target) internal view {
        // @note check more `_target` address to avoid attack in the future when we add more external contracts.
        require(_target != address(this), "Forbid to call self");
    }

    /*//////////////////////////////////////////////////////////////////////////
                             RESTRICTED FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IL1BridgeMessenger
    function setPause(bool _status) external onlyOwner {
        if (_status) {
            _pause();
        } else {
            _unpause();
        }
    }

    /// @inheritdoc IL1BridgeMessenger
    function transferOwnershipRole(address newOwner) external override onlyOwner {
        _revokeRole(OWNER_ROLE, owner());
        super.transferOwnership(newOwner);
        _grantRole(OWNER_ROLE, newOwner);
    }
}
