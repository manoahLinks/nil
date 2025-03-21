// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { NilAccessControlUpgradeable } from "../../NilAccessControlUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { AccessControlEnumerableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { NilConstants } from "../../common/libraries/NilConstants.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IL2BridgeMessenger } from "./interfaces/IL2BridgeMessenger.sol";
import { IBridgeMessenger } from "../interfaces/IBridgeMessenger.sol";
import { IL2Bridge } from "./interfaces/IL2Bridge.sol";
import { NilMerkleTree } from "./libraries/NilMerkleTree.sol";
import { ErrorInvalidMessageType } from "../../common/NilErrorConstants.sol";
import { AddressChecker } from "../../common/libraries/AddressChecker.sol";

/// @title L2BridgeMessenger
/// @notice The `L2BridgeMessenger` contract can:
/// 1. send messages from nil-chain to layer 1
/// 2. receive relayed messages from L1 via relayer
/// 3. entrypoint for all messages relayed from layer-1 to nil-chain via relayer
contract L2BridgeMessenger is OwnableUpgradeable, PausableUpgradeable, NilAccessControlUpgradeable, IL2BridgeMessenger {
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.Bytes32Set;
  using AddressChecker for address;

  /*//////////////////////////////////////////////////////////////////////////
                                  STATE VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

  /// @notice address of the bridgeMessenger from counterpart (L1) chain
  address public counterpartyBridgeMessenger;

  /// @notice Mapping from L2 message hash to the timestamp when the message is sent.
  mapping(bytes32 => uint256) public l2MessageSentTimestamp;

  /// @notice  Holds the addresses of authorized bridges that can interact to send messages.
  EnumerableSet.AddressSet private authorizedBridges;

  /// @notice EnumerableSet for messageHash of the message relayed by relayer on behalf of L1BridgeMessenger
  EnumerableSet.Bytes32Set private relayedMessageHashStore;

  /// @notice EnumerableSet for messageHash of relayed-messages which failed execution in Nil-Shard
  EnumerableSet.Bytes32Set private failedMessageHashStore;

  /// @notice the aggregated hash for all message-hash values received by the l2BridgeMessenger
  /// @dev initialize with the genesis state Hash during the contract initialisation
  bytes32 public l1ReceiveMessageHash;

  /// @notice merkleRoot of the merkleTree with messageHash of the relayed messages with failedExecution and withdrawalMessages sent from messenger.
  bytes32 public l2Tol1Root;

  /// @notice address of the relayer nil-smart-account which is authorized to relay messages from L1BridgeMessenger
  address public relayer;

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
    address _relayer,
    address _counterpartyBridgeMessenger,
    bytes32 _genesisL1ReceiveMessageHash
  ) public initializer {
    // Validate input parameters
    if (_owner == address(0)) {
      revert ErrorInvalidOwner();
    }

    if (_defaultAdmin == address(0)) {
      revert ErrorInvalidDefaultAdmin();
    }

    if (!_counterpartyBridgeMessenger.isContract()) {
      revert ErrorInvalidCounterpartBridgeMessenger();
    }

    // TODO - validate if _relayer is a Nil-Smart-Account
    if (_relayer == address(0)) {
      revert ErrorInvalidAddress();
    }

    // Initialize the Ownable contract with the owner address
    OwnableUpgradeable.__Ownable_init(_owner);

    // Initialize the Pausable contract
    PausableUpgradeable.__Pausable_init();

    // Initialize the AccessControlEnumerable contract
    __AccessControlEnumerable_init();

    // Set role admins
    // The OWNER_ROLE is set as its own admin to ensure that only the current owner can manage this role.
    _setRoleAdmin(NilConstants.OWNER_ROLE, NilConstants.OWNER_ROLE);

    // The DEFAULT_ADMIN_ROLE is set as its own admin to ensure that only the current default admin can manage this
    // role.
    _setRoleAdmin(DEFAULT_ADMIN_ROLE, NilConstants.OWNER_ROLE);

    // Grant roles to defaultAdmin and owner
    // The DEFAULT_ADMIN_ROLE is granted to both the default admin and the owner to ensure that both have the
    // highest level of control.
    // The OWNER_ROLE is granted to the owner to ensure they have the highest level of control over the contract.
    _grantRole(NilConstants.OWNER_ROLE, _owner);
    _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);

    _grantRole(NilConstants.RELAYER_ROLE_ADMIN, _defaultAdmin);
    _grantRole(NilConstants.RELAYER_ROLE_ADMIN, _owner);
    _grantRole(NilConstants.RELAYER_ROLE, _owner);
    _grantRole(NilConstants.RELAYER_ROLE, _defaultAdmin);
    _grantRole(NilConstants.RELAYER_ROLE, _relayer);

    relayer = _relayer;
    counterpartyBridgeMessenger = _counterpartyBridgeMessenger;
    l1ReceiveMessageHash = _genesisL1ReceiveMessageHash;
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

  /// @inheritdoc IL2BridgeMessenger
  function getAuthorizedBridges() public view returns (address[] memory) {
    return authorizedBridges.values();
  }

  function isAuthorisedBridge(address bridgeAddress) public view returns (bool) {
    return authorizedBridges.contains(bridgeAddress);
  }

  /*//////////////////////////////////////////////////////////////////////////
                         PUBLIC MUTATION FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IL2BridgeMessenger
  function sendMessage(
    address messageTarget,
    uint256 value,
    bytes memory message,
    uint256 gasLimit,
    address refundRecipient
  ) public payable override whenNotPaused {}

  /// @inheritdoc IL2BridgeMessenger
  // TODO - only relayer-pubKey check
  function relayMessage(
    address messageSender,
    address messageTarget,
    NilConstants.MessageType messageType,
    uint256 value,
    uint256 messagNonce,
    bytes memory message
  ) external override whenNotPaused {
    if (messageType != NilConstants.MessageType.DEPOSIT_ERC20 && messageType != NilConstants.MessageType.DEPOSIT_ETH) {
      revert ErrorInvalidMessageType();
    }

    bytes32 _l1MessageHash = computeMessageHash(messageSender, messageTarget, value, messagNonce, message);

    if (relayedMessageHashStore.contains(_l1MessageHash)) {
      revert ErrorDuplicateMessageRelayed(_l1MessageHash);
    }

    relayedMessageHashStore.add(_l1MessageHash);

    if (l1ReceiveMessageHash == bytes32(0)) {
      l1ReceiveMessageHash = _l1MessageHash;
    } else {
      l1ReceiveMessageHash = keccak256(abi.encode(_l1MessageHash, l1ReceiveMessageHash));
    }

    bool isExecutionSuccessful = _executeMessage(messageSender, messageTarget, value, message);

    if (!isExecutionSuccessful) {
      // add messaheHash as leaf to the merkleTree represented by l2Tol1Root
      failedMessageHashStore.add(_l1MessageHash);

      // re-generate the merkle-tree
      bytes32 merkleRoot = NilMerkleTree.computeMerkleRoot(failedMessageHashStore.values());

      // merkleRoot must change from the existing root in messenger-contract storage
      if (l2Tol1Root == merkleRoot || merkleRoot == bytes32(0)) {
        revert ErrorInvalidMerkleRoot();
      }

      emit MessageRelayFailed(_l1MessageHash);
    } else {
      emit MessageRelaySuccessful(_l1MessageHash);
    }
  }

  /// @inheritdoc IL2BridgeMessenger
  function computeMessageHash(
    address _messageSender,
    address _messageTarget,
    uint256 _value,
    uint256 _messageNonce,
    bytes memory _message
  ) public pure override returns (bytes32) {
    // TODO - convert keccak256 to precompile call for realkeccak256 in nil-shard
    return keccak256(abi.encode(_messageSender, _messageTarget, _value, _messageNonce, _message));
  }

  /*//////////////////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

  function _executeMessage(
    address _messageSender,
    address _messageTarget,
    uint256 _value,
    bytes memory _message
  ) internal returns (bool) {
    // @note check `_messageTarget` address to avoid attack in the future when we add more gateways.
    if (!isAuthorisedBridge(_messageTarget)) {
      revert ErrorBridgeNotAuthorised();
    }
    (bool isSuccessful, ) = (_messageTarget).call{ value: _value }(_message);
    return isSuccessful;
  }

  /*//////////////////////////////////////////////////////////////////////////
                         RESTRICTED FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

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

  /// @inheritdoc IL2BridgeMessenger
  function setPause(bool _status) external onlyAdmin {
    if (_status) {
      _pause();
    } else {
      _unpause();
    }
  }

  /// @inheritdoc IBridgeMessenger
  function transferOwnershipRole(address newOwner) external override onlyOwner {
    _revokeRole(NilConstants.OWNER_ROLE, owner());
    super.transferOwnership(newOwner);
    _grantRole(NilConstants.OWNER_ROLE, newOwner);
  }

  /// @inheritdoc IERC165
  function supportsInterface(
    bytes4 interfaceId
  ) public view override(AccessControlEnumerableUpgradeable, IERC165) returns (bool) {
    return interfaceId == type(IL2BridgeMessenger).interfaceId || super.supportsInterface(interfaceId);
  }
}
