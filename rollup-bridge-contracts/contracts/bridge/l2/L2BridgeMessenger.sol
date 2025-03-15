// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IL2BridgeMessenger } from "./interfaces/IL2BridgeMessenger.sol";
import { IBridgeMessenger } from "../interfaces/IBridgeMessenger.sol";
import { NilRoleConstants } from "../../libraries/NilRoleConstants.sol";
import { IL2Bridge } from "./interfaces/IL2Bridge.sol";

/// @title L2BridgeMessenger
/// @notice The `L2BridgeMessenger` contract can:
/// 1. send messages from nil-chain to layer 1
/// 2. entrypoint for the messages relayed from layer-1 to nil-chain
/// @dev It should be a predeployed contract on nil-shard
contract L2BridgeMessenger is IL2BridgeMessenger, ReentrancyGuard, AccessControl, Ownable, Pausable {
  using EnumerableSet for EnumerableSet.AddressSet;

  /*//////////////////////////////////////////////////////////////////////////
                                  STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

  /// @notice address of the bridgeMessenger from counterpart (L1) chain
  address public counterpartBridgeMessenger;

  /// @notice Mapping from L2 message hash to the timestamp when the message is sent.
  mapping(bytes32 => uint256) public l2MessageSentTimestamp;

  mapping(bytes32 => bool) public l1MessageExecutionState;

  /// @notice Mapping from L1 message hash to a boolean value indicating if the message has been successfully executed.
  mapping(bytes32 => bool) public l1MessageTracker;

  /// @notice  Holds the addresses of authorized bridges that can interact to send messages.
  EnumerableSet.AddressSet private authorizedBridges;

  /// @notice the aggregated hash for all message-hash values received by the l2BridgeMessenger
  /// @dev initialize with the genesis state Hash during the contract initialisation
  bytes32 public l1ReceiveMessageHash;

  /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

  constructor(
    address _owner,
    address _admin,
    address _counterpartBridgeMessenger,
    bytes32 _genesisL1ReceiveMessageHash
  ) Ownable(_owner) {
    counterpartBridgeMessenger = _counterpartBridgeMessenger;
    l1ReceiveMessageHash = _genesisL1ReceiveMessageHash;
    _grantRole(NilRoleConstants.OWNER_ROLE, _owner);
    _grantRole(DEFAULT_ADMIN_ROLE, _admin);
  }

  // make sure only owner can send ether to messenger to avoid possible user fund loss.
  receive() external payable onlyOwner {}

  /*//////////////////////////////////////////////////////////////////////////
                             MODIFIERS  
    //////////////////////////////////////////////////////////////////////////*/

  modifier onlyAuthorizedL2Bridge() {
    if (!authorizedBridges.contains(msg.sender)) {
      revert ErrorBridgeNotAuthorised();
    }
    _;
  }

  modifier onlyAdmin() {
    if (!(hasRole(DEFAULT_ADMIN_ROLE, msg.sender))) {
      revert ErrorCallerIsNotAdmin();
    }
    _;
  }

  /// @inheritdoc IL2BridgeMessenger
  function getAuthorizedBridges() external view returns (address[] memory) {
    return authorizedBridges.values();
  }

  /// @inheritdoc IERC165
  function supportsInterface(bytes4 interfaceId) public view override(AccessControl, IERC165) returns (bool) {
    return interfaceId == type(IL2BridgeMessenger).interfaceId || super.supportsInterface(interfaceId);
  }

  /*//////////////////////////////////////////////////////////////////////////
                         PUBLIC MUTATION FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IL2BridgeMessenger
  function sendMessage(
    address _to,
    uint256 _value,
    bytes calldata _message,
    uint256 _gasLimit,
    address
  ) external payable override whenNotPaused {
    _sendMessage(_to, _value, _message, _gasLimit);
  }

  /// @inheritdoc IL2BridgeMessenger
  function relayMessage(
    address messageSender,
    address messageTarget,
    uint256 value,
    uint256 messagNonce,
    bytes memory message
  ) external override whenNotPaused {
    bytes32 _l1MessageHash = computeMessageHash(messageSender, messageTarget, value, messagNonce, message);

    require(!l1MessageExecutionState[_l1MessageHash], "Message was already successfully executed");

    _executeMessage(messageSender, messageTarget, value, message, _l1MessageHash);
  }

  /// @inheritdoc IL2BridgeMessenger
  function computeMessageHash(
    address _messageSender,
    address _messageTarget,
    uint256 _value,
    uint256 _messageNonce,
    bytes memory _message
  ) public pure override returns (bytes32) {
    return keccak256(abi.encode(_messageSender, _messageTarget, _value, _messageNonce, _message));
  }

  /*//////////////////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

  function _executeMessage(
    address _messageSender,
    address _messageTarget,
    uint256 _value,
    bytes memory _message,
    bytes32 _messageHash
  ) internal {}

  /// @dev Internal function to send cross domain message.
  /// @param _to The address of account who receive the message.
  /// @param _value The amount of ether passed when call target contract.
  /// @param _message The content of the message.
  /// @param _gasLimit Optional gas limit to complete the message relay on corresponding chain.
  function _sendMessage(address _to, uint256 _value, bytes memory _message, uint256 _gasLimit) internal nonReentrant {}

  /*//////////////////////////////////////////////////////////////////////////
                         RESTRICTED FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IL2BridgeMessenger
  function setPause(bool _status) external onlyAdmin {
    if (_status) {
      _pause();
    } else {
      _unpause();
    }
  }

  /// @inheritdoc IL2BridgeMessenger
  function authorizeBridges(address[] calldata bridges) external onlyAdmin {
    for (uint256 i = 0; i < bridges.length; i++) {
      _authorizeBridge(bridges[i]);
    }
  }

  /// @inheritdoc IL2BridgeMessenger
  function authorizeBridge(address bridge) external override onlyAdmin {
    _authorizeBridge(bridge);
  }

  function _authorizeBridge(address bridge) internal {
    if (!IERC165(bridge).supportsInterface(type(IL2Bridge).interfaceId)) {
      revert ErrorInvalidBridgeInterface();
    }
    if (authorizedBridges.contains(bridge)) {
      revert ErrorBridgeAlreadyAuthorized();
    }
    authorizedBridges.add(bridge);
  }

  /// @inheritdoc IL2BridgeMessenger
  function revokeBridgeAuthorization(address bridge) external override onlyAdmin {
    if (!authorizedBridges.contains(bridge)) {
      revert ErrorBridgeNotAuthorised();
    }
    authorizedBridges.remove(bridge);
  }

  /// @inheritdoc IBridgeMessenger
  function transferOwnershipRole(address newOwner) external override onlyOwner {
    _revokeRole(NilRoleConstants.OWNER_ROLE, owner());
    super.transferOwnership(newOwner);
    _grantRole(NilRoleConstants.OWNER_ROLE, newOwner);
  }
}
