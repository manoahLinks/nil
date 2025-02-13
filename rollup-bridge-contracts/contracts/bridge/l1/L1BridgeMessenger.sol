// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IL1BridgeMessenger } from "./interfaces/IL1BridgeMessenger.sol";
import { Queue } from "../libraries/Queue.sol";

abstract contract L1BridgeMessenger is
  OwnableUpgradeable,
  PausableUpgradeable,
  ReentrancyGuardUpgradeable,
  IL1BridgeMessenger
{
  using Queue for Queue.QueueData;

  /*//////////////////////////////////////////////////////////////////////////
                             STATE-VARIABLES   
    //////////////////////////////////////////////////////////////////////////*/

  // Add this mapping to store deposit messages by their message hash
  mapping(bytes32 => DepositMessage) public depositMessages;

  /// @notice The cumulative hash of all messages.
  bytes32 public l1MessageHash;

  /// @notice The nonce for deposit messages.
  uint256 public depositNonce;

  /// @notice Queue to store message hashes
  Queue.QueueData private messageQueue;

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

  function initialize(address _owner, bytes32 _genesisL1MessageHash) public initializer {
    OwnableUpgradeable.__Ownable_init(_owner);
    PausableUpgradeable.__Pausable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    if (_genesisL1MessageHash == bytes32(0)) {
      revert ErrorInvalidHash();
    }

    l1MessageHash = _genesisL1MessageHash;
    depositNonce = 0;
  }

  // make sure only owner can send ether to messenger to avoid possible user fund loss.
  receive() external payable onlyOwner {}

  /*//////////////////////////////////////////////////////////////////////////
                             PUBLIC CONSTANT FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

  /// @notice Gets the current deposit nonce.
  /// @return The current deposit nonce.
  function getCurrentDepositNonce() public view returns (uint256) {
    return depositNonce;
  }

  /// @notice Gets the next deposit nonce.
  /// @return The next deposit nonce.
  function getNextDepositNonce() public view returns (uint256) {
    return depositNonce + 1;
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

  /*//////////////////////////////////////////////////////////////////////////
                             INTERNAL FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

  /// @notice Updates the l1MessageHash with the new deposit message hash.
  /// @param currentDepositMessageHash The hash of the current deposit message.
  function updateDepositMessageHash(bytes32 currentDepositMessageHash) internal {
    if (currentDepositMessageHash == bytes32(0)) {
      revert ErrorInvalidHash();
    }

    l1MessageHash = keccak256(abi.encodePacked(l1MessageHash, currentDepositMessageHash));
  }

  /*****************************
   * Public Mutating Functions *
   *****************************/

  /// @inheritdoc IL1BridgeMessenger
  function sendMessage(
    address _to,
    uint256 _value,
    bytes memory _message,
    uint256 _gasLimit
  ) external payable override whenNotPaused {
    _sendMessage(_to, _value, _message, _gasLimit, _msgSender());
  }

  /// @inheritdoc IL1BridgeMessenger
  function sendMessage(
    address _to,
    uint256 _value,
    bytes calldata _message,
    uint256 _gasLimit,
    address _refundAddress
  ) external payable override whenNotPaused {
    _sendMessage(_to, _value, _message, _gasLimit, _refundAddress);
  }

  function _sendMessage(
    address _to,
    uint256 _amount,
    bytes memory _message,
    uint256 _gasLimit,
    address _refundAddress // TODO to be used in refundFee internal function
  ) internal nonReentrant {
    // Create the DepositMessage struct
    DepositMessage memory depositMessage = DepositMessage({
      nonce: depositNonce,
      gasLimit: _gasLimit,
      expiryTime: block.timestamp + 5 hours,
      message: _message,
      isCancelled: false
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
    emit MessageSent(_msgSender(), _to, _amount, depositMessage.nonce, _gasLimit, depositMessage.expiryTime, _message);

    // Increment the deposit nonce
    depositNonce++;
  }

  function _computeMessageHash(DepositMessage memory depositMessage) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          depositMessage.nonce,
          depositMessage.gasLimit,
          depositMessage.expiryTime,
          depositMessage.message
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
