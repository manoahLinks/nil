// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IL1BridgeMessenger } from "./interfaces/IL1BridgeMessenger.sol";
import { IL1Bridge } from "./interfaces/IL1Bridge.sol";
import { Queue } from "../libraries/Queue.sol";

contract L1BridgeMessenger is
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    IL1BridgeMessenger
{
    using Queue for Queue.QueueData;
    using EnumerableSet for EnumerableSet.AddressSet;

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

    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////////////////
                             INITIALIZER   
    //////////////////////////////////////////////////////////////////////////*/

    function initialize(
        address _owner,
        address _l1NilRollup,
        uint256 _maxProcessingTime,
        uint256 _cancelTimeDelta
    )
        public
        initializer
    {
        OwnableUpgradeable.__Ownable_init(_owner);
        PausableUpgradeable.__Pausable_init();
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

    /// @notice Pause the contract
    /// @dev This function can only called by contract owner.
    /// @param _status The pause status to update.
    function setPause(bool _status) external onlyOwner {
        if (_status) {
            _pause();
        } else {
            _unpause();
        }
    }

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
    function popMessages(uint256 messageCount) external override {
        if (_msgSender() != l1NilRollup) {
            revert NotAuthorizedToPopMessages();
        }

        messageQueue.popFrontBatch(messageCount);
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
        address _refundAddress // TODO to be used in refundFee internal function
    )
        internal
        nonReentrant
    {
        // Create the DepositMessage struct
        DepositMessage memory depositMessage = DepositMessage({
            from: _msgSender(),
            nonce: depositNonce,
            gasLimit: _gasLimit,
            expiryTime: block.timestamp + maxProcessingTime,
            message: _message,
            isCancelled: false,
            depositType: _depositType
        });

        // Compute the message hash
        bytes32 messageHash = _computeMessageHash(depositMessage);

        //perform duplicate message check
        if (depositMessages[messageHash].expiryTime > 0) {
            revert DepositMessageAlreadyExist(messageHash);
        }

        // Store the deposit message in the mapping
        depositMessages[messageHash] = depositMessage;

        // TODO add messageHash to queue
        messageQueue.pushBack(messageHash);

        // Emit the event
        emit MessageSent(
            _msgSender(),
            _to,
            _depositType,
            _amount,
            depositMessage.nonce,
            _gasLimit,
            depositMessage.expiryTime,
            _message
        );

        // Increment the deposit nonce
        depositNonce++;
    }

    function _computeMessageHash(DepositMessage memory depositMessage) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                depositMessage.nonce, depositMessage.gasLimit, depositMessage.expiryTime, depositMessage.message
            )
        );
    }

    /// @dev Internal function to check whether the `_target` address is allowed to avoid attack.
    /// @param _target The address of target address to check.
    function _validateTargetAddress(address _target) internal view {
        // @note check more `_target` address to avoid attack in the future when we add more external contracts.

        require(_target != address(this), "Forbid to call self");
    }
}
