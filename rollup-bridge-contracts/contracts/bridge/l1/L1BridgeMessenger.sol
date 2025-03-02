// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { AccessControlEnumerableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IL1BridgeMessenger } from "./interfaces/IL1BridgeMessenger.sol";
import { IBridgeMessenger } from "../interfaces/IBridgeMessenger.sol";
import { IL1Bridge } from "./interfaces/IL1Bridge.sol";
import { NilAccessControl } from "../../NilAccessControl.sol";
import { BaseBridgeMessenger } from "../BaseBridgeMessenger.sol";
import { Queue } from "../libraries/Queue.sol";
import { INilGasPriceOracle } from "./interfaces/INilGasPriceOracle.sol";

contract L1BridgeMessenger is BaseBridgeMessenger, IL1BridgeMessenger {
  using Queue for Queue.QueueData;
  using EnumerableSet for EnumerableSet.AddressSet;

  struct SendMessageParams {
    DepositType depositType;
    address messageTarget;
    uint256 value;
    bytes message;
    uint256 gasLimit;
    address refundAddress;
    INilGasPriceOracle.FeeCreditData feeCreditData;
  }

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
    uint256 _cancelTimeDelta,
    address _counterpartMessenger
  ) public initializer {
    // Validate input parameters
    if (_owner == address(0)) {
      revert ErrorInvalidOwner();
    }

    if (_defaultAdmin == address(0)) {
      revert ErrorInvalidDefaultAdmin();
    }

    BaseBridgeMessenger.__BaseBridgeMessenger_init(_owner, _defaultAdmin, _counterpartMessenger);

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
    address messageTarget,
    uint256 value,
    bytes memory message,
    uint256 gasLimit,
    INilGasPriceOracle.FeeCreditData memory feeCreditData
  ) external payable override whenNotPaused onlyAuthorizedL1Bridge {
    _sendMessage(
      SendMessageParams({
        depositType: depositType,
        messageTarget: messageTarget,
        value: value,
        message: message,
        gasLimit: gasLimit,
        refundAddress: _msgSender(),
        feeCreditData: feeCreditData
      })
    );
  }

  /// @inheritdoc IL1BridgeMessenger
  function sendMessage(
    DepositType depositType,
    address messageTarget,
    uint256 value,
    bytes calldata message,
    uint256 gasLimit,
    address refundAddress,
    INilGasPriceOracle.FeeCreditData memory feeCreditData
  ) external payable override whenNotPaused onlyAuthorizedL1Bridge {
    _sendMessage(
      SendMessageParams({
        depositType: depositType,
        messageTarget: messageTarget,
        value: value,
        message: message,
        gasLimit: gasLimit,
        refundAddress: refundAddress,
        feeCreditData: feeCreditData
      })
    );
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

  function _sendMessage(SendMessageParams memory params) internal nonReentrant {
    DepositMessage memory depositMessage = _createDepositMessage(params);
    bytes32 messageHash = computeMessageHash(
      _msgSender(),
      params.messageTarget,
      params.value,
      depositMessage.nonce,
      params.message
    );

    require(depositMessages[messageHash].expiryTime == 0, "DepositMessageAlreadyExist");
    depositMessages[messageHash] = depositMessage;
    messageQueue.pushBack(messageHash);

    emit MessageSent(
      _msgSender(),
      params.messageTarget,
      params.value,
      depositMessage.nonce,
      depositMessage.gasLimit,
      params.message,
      messageHash,
      params.depositType,
      params.refundAddress,
      block.timestamp,
      params.feeCreditData
    );
  }

  function _createDepositMessage(SendMessageParams memory params) internal returns (DepositMessage memory) {
    return
      DepositMessage({
        sender: _msgSender(),
        target: params.messageTarget,
        value: params.value,
        nonce: depositNonce++,
        gasLimit: params.gasLimit,
        expiryTime: block.timestamp + maxProcessingTime,
        isCancelled: false,
        refundAddress: params.refundAddress,
        depositType: params.depositType,
        message: params.message,
        feeCreditData: params.feeCreditData
      });
  }

  function supportsInterface(
    bytes4 interfaceId
  ) public view override(AccessControlEnumerableUpgradeable, IERC165) returns (bool) {
    return interfaceId == type(IL1Bridge).interfaceId || interfaceId == type(IERC165).interfaceId;
  }
}
