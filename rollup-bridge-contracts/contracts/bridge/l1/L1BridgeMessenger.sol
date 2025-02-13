// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IL1BridgeMessenger } from "./interfaces/IL1BridgeMessenger.sol";

abstract contract L1BridgeMessenger is
  OwnableUpgradeable,
  PausableUpgradeable,
  ReentrancyGuardUpgradeable,
  IL1BridgeMessenger
{
  /*//////////////////////////////////////////////////////////////////////////
                             STATE-VARIABLES   
    //////////////////////////////////////////////////////////////////////////*/

  // Add this mapping to store deposit messages by their message hash
  mapping(bytes32 => DepositMessage) public depositMessages;

  /// @notice The cumulative hash of all messages.
  bytes32 public l1MessageHash;

  /// @notice The nonce for deposit messages.
  uint256 public depositNonce;

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

  /// @notice Sends a message to the nil-chain.
  /// @param from The original sender of the ERC20 tokens who has deposited in bridge in layer-1.
  /// @param to The recipient address on nil-chain.
  /// @param amount The amount of tokens to send.
  /// @param gasLimit The gas limit required to complete the transaction on nil-chain.
  /// @param refundAddress The address to refund if the transaction fails.
  /// @param l1TokenAddress The address of the ERC20 token on layer-1.
  /// @param l2TokenAddress The address of the corresponding ERC20 token on nil-chain.
  function sendMessage(
    address from,
    address to,
    uint256 amount,
    uint256 gasLimit,
    address refundAddress,
    address l1TokenAddress,
    address l2TokenAddress
  ) public {
    // Validate input parameters
    if (from == address(0)) {
      revert ErrorZeroAddress();
    }
    if (to == address(0)) {
      revert ErrorZeroAddress();
    }
    if (refundAddress == address(0)) {
      revert ErrorZeroAddress();
    }
    if (l1TokenAddress == address(0)) {
      revert ErrorZeroAddress();
    }
    if (l2TokenAddress == address(0)) {
      revert ErrorZeroAddress();
    }
    if (amount == 0) {
      revert ErrorInvalidAmount();
    }
    if (gasLimit == 0) {
      revert ErrorInvalidGasLimit();
    }

    _sendMessage(from, to, amount, gasLimit, refundAddress, l1TokenAddress, l2TokenAddress);
  }

  function _sendMessage(
    address _from,
    address _to,
    uint256 _amount,
    uint256 _gasLimit,
    address _refundAddress,
    address _l1TokenAddress,
    address _l2TokenAddress
  ) internal nonReentrant {
    // Get the current nonce
    uint256 currentNonce = depositNonce;

    // Create the DepositMessage struct
    DepositMessage memory depositMessage = DepositMessage({
      from: _from,
      recipient: _to,
      refundAddress: _refundAddress,
      l1TokenAddress: _l1TokenAddress,
      l2TokenAddress: _l2TokenAddress,
      amount: _amount,
      nonce: currentNonce,
      gasLimit: _gasLimit,
      expiryTime: block.timestamp + 5 hours
    });

    // Compute the message hash
    bytes32 messageHash = _computeMessageHash(depositMessage);

    // queue

    // Store the deposit message in the mapping
    depositMessages[messageHash] = depositMessage;

    // message (finalizeDeposit)

    // Emit the event
    emit MessageSent(
      _from,
      _to,
      _amount,
      _gasLimit,
      _refundAddress,
      _l1TokenAddress,
      _l2TokenAddress,
      currentNonce,
      messageHash,
      depositMessage.expiryTime
    );

    // Increment the deposit nonce
    depositNonce++;
  }

  function _computeMessageHash(DepositMessage memory depositMessage) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encodePacked(
          depositMessage.from,
          depositMessage.recipient,
          depositMessage.refundAddress,
          depositMessage.l1TokenAddress,
          depositMessage.l2TokenAddress,
          depositMessage.amount,
          depositMessage.nonce,
          depositMessage.gasLimit,
          depositMessage.expiryTime
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
