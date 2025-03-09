// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { AccessControlEnumerableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IBridgeMessenger } from "../interfaces/IBridgeMessenger.sol";
import { NilAccessControl } from "../../NilAccessControl.sol";
import { IL1BridgeMessenger } from "./interfaces/IL1BridgeMessenger.sol";
import { IBridgeMessenger } from "../interfaces/IBridgeMessenger.sol";
import { IL1Bridge } from "./interfaces/IL1Bridge.sol";
import { INilRollup } from "../../interfaces/INilRollup.sol";
import { NilAccessControl } from "../../NilAccessControl.sol";
import { Queue } from "../libraries/Queue.sol";
import { INilGasPriceOracle } from "./interfaces/INilGasPriceOracle.sol";
import { NilRoleConstants } from "../../libraries/NilRoleConstants.sol";

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

  error ErrorInvalidClaimProof();

  /*//////////////////////////////////////////////////////////////////////////
                             STRUCTS   
    //////////////////////////////////////////////////////////////////////////*/

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
  uint256 public override depositNonce;

  /// @notice Queue to store message hashes
  Queue.QueueData private messageQueue;

  /**
   * @notice Maximum processing time allowed for a deposit to be executed on L2.
   * @dev This variable is used to determine the maximum time for deposit execution on L2.
   * The total time for execution is calculated as deposit-time + max-processing-time.
   */
  uint256 public maxProcessingTime;

  /**
   * @notice Holds the addresses of authorized bridges that can interact to send messages.
   */
  EnumerableSet.AddressSet private authorizedBridges;

  /// @notice address of the NilRollup contracrt on L1
  address private l1NilRollup;

  /// @notice The address of counterpart BridgeMessenger contract in L1/NilChain.
  address public counterpartMessenger;

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
    address _counterpartMessenger
  ) public initializer {
    // Validate input parameters
    if (_owner == address(0)) {
      revert ErrorInvalidOwner();
    }

    if (_defaultAdmin == address(0)) {
      revert ErrorInvalidDefaultAdmin();
    }

    if (_owner == address(0)) {
      revert ErrorInvalidOwner();
    }

    if (_defaultAdmin == address(0)) {
      revert ErrorInvalidDefaultAdmin();
    }

    if (_maxProcessingTime == 0) {
      revert InvalidMaxMessageProcessingTime();
    }

    // Initialize the Ownable contract with the owner address
    OwnableUpgradeable.__Ownable_init(_owner);

    // Initialize the Pausable contract
    PausableUpgradeable.__Pausable_init();

    // Initialize the AccessControlEnumerable contract
    __AccessControlEnumerable_init();

    // Set role admins
    // The OWNER_ROLE is set as its own admin to ensure that only the current owner can manage this role.
    _setRoleAdmin(NilRoleConstants.OWNER_ROLE, NilRoleConstants.OWNER_ROLE);

    // The DEFAULT_ADMIN_ROLE is set as its own admin to ensure that only the current default admin can manage this
    // role.
    _setRoleAdmin(DEFAULT_ADMIN_ROLE, NilRoleConstants.OWNER_ROLE);

    // Grant roles to defaultAdmin and owner
    // The DEFAULT_ADMIN_ROLE is granted to both the default admin and the owner to ensure that both have the
    // highest level of control.
    // The PROPOSER_ROLE_ADMIN is granted to both the default admin and the owner to allow them to manage proposers.
    // The OWNER_ROLE is granted to the owner to ensure they have the highest level of control over the contract.
    _grantRole(NilRoleConstants.OWNER_ROLE, _owner);
    _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);

    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    maxProcessingTime = _maxProcessingTime;
    depositNonce = 0;
    counterpartMessenger = _counterpartMessenger;
    l1NilRollup = _l1NilRollup;
  }

  // make sure only owner can send ether to messenger to avoid possible user fund loss.
  receive() external payable onlyOwner {}

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

  function computeMessageHash(
    address _messageSender,
    address _messageTarget,
    uint256 _value,
    uint256 _messageNonce,
    bytes memory _message
  ) public pure returns (bytes32) {
    return keccak256(abi.encode(_messageSender, _messageTarget, _value, _messageNonce, _message));
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
    _revokeRole(NilRoleConstants.OWNER_ROLE, owner());
    super.transferOwnership(newOwner);
    _grantRole(NilRoleConstants.OWNER_ROLE, newOwner);
  }

  /// @dev Internal function to check whether the `_target` address is allowed to avoid attack.
  /// @param _target The address of target address to check.
  function _validateTargetAddress(address _target) internal view {
    // @note check more `_target` address to avoid attack in the future when we add more external contracts.
    require(_target != address(this), "Forbid to call self");
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

    // Check if the current time is greater than the expiration time with delta
    if (block.timestamp <= depositMessage.expiryTime) {
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
    if (messageCount > messageQueue.getSize()) {
      revert NotEnoughMessagesInQueue();
    }

    bytes32[] memory poppedMessages = messageQueue.popFrontBatch(messageCount);

    if (poppedMessages.length != messageCount) {
      revert NotEnoughMessagesInQueue();
    }

    return poppedMessages;
  }

  /// @inheritdoc IL1BridgeMessenger
  function claimFailedDeposit(bytes32 messageHash, bytes32[] memory claimProof) public override {
    DepositMessage storage depositMessage = depositMessages[messageHash];
    if (depositMessage.expiryTime == 0) {
      revert DepositMessageDoesNotExist(messageHash);
    }

    // Check if the deposit message is already claimed
    if (depositMessage.isClaimed) {
      revert DepositMessageAlreadyClaimed();
    }

    // Check if the message hash is not in the queue
    if (messageQueue.contains(messageHash)) {
      revert DepositMessageStillInQueue();
    }

    bytes32 l2Tol1Root = INilRollup(l1NilRollup).getCurrentL2ToL1Root();
    if (!MerkleProof.verify(claimProof, l2Tol1Root, messageHash)) {
      revert ErrorInvalidClaimProof();
    }

    depositMessage.isClaimed = true;
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
        isClaimed: false,
        refundAddress: params.refundAddress,
        depositType: params.depositType,
        message: params.message,
        feeCreditData: params.feeCreditData
      });
  }

  /// @inheritdoc IERC165
  function supportsInterface(
    bytes4 interfaceId
  ) public view override(AccessControlEnumerableUpgradeable, IERC165) returns (bool) {
    return interfaceId == type(IL1BridgeMessenger).interfaceId || super.supportsInterface(interfaceId);
  }
}
