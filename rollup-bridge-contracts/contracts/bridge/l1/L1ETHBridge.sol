// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { NilAccessControlUpgradeable } from "../../NilAccessControlUpgradeable.sol";
import { IL1ETHBridge } from "./interfaces/IL1ETHBridge.sol";
import { IL2ETHBridge } from "../l2/interfaces/IL2ETHBridge.sol";
import { IL1BridgeRouter } from "./interfaces/IL1BridgeRouter.sol";
import { IL1Bridge } from "./interfaces/IL1Bridge.sol";
import { IBridge } from "../interfaces/IBridge.sol";
import { IL1BridgeMessenger } from "./interfaces/IL1BridgeMessenger.sol";
import { INilGasPriceOracle } from "./interfaces/INilGasPriceOracle.sol";
import { L1BaseBridge } from "./L1BaseBridge.sol";

/// @title L1ETHBridge
/// @notice The `L1ETHBridge` contract for ETH bridging from L1.
contract L1ETHBridge is L1BaseBridge, IL1ETHBridge {
  // Define the function selector for finalizeDepositETH as a constant
  bytes4 public constant FINALIZE_DEPOSIT_ETH_SELECTOR = IL2ETHBridge.finalizeETHDeposit.selector;

  /*//////////////////////////////////////////////////////////////////////////
                             ERRORS   
    //////////////////////////////////////////////////////////////////////////*/

  /// @dev Failed to refund ETH for the depositMessage
  error ErrorEthRefundFailed(bytes32 messageHash);

  /// @dev Error due to Zero eth-deposit
  error ErrorZeroEthDeposit();

  /// @dev Error due to invalid l2 recipient address
  error ErrorInvalidL2Recipient();

  /// @dev Error due to invalid L2 GasLimit
  error ErrorInvalidL2GasLimit();

  /*//////////////////////////////////////////////////////////////////////////
                             STATE-VARIABLES   
    //////////////////////////////////////////////////////////////////////////*/

  /// @notice address of ETH token on l2
  /// @dev ETH on L2 is an ERC20Token
  address public override l2EthAddress;

  /// @dev The storage slots for future usage.
  uint256[50] private __gap;

  /*//////////////////////////////////////////////////////////////////////////
                             CONSTRUCTOR   
    //////////////////////////////////////////////////////////////////////////*/

  /// @notice Constructor for `L1ETHBridge` implementation contract.
  constructor() {
    _disableInitializers();
  }

  /// @notice Initialize the storage of L1ETHBridge.
  /// @param _owner The owner of L1ETHBridge in layer-1.
  /// @param _counterPartyETHBridge The address of ETHBridge on nil-chain
  /// @param _messenger The address of NilMessenger in layer-1.
  function initialize(
    address _owner,
    address _defaultAdmin,
    address _counterPartyETHBridge,
    address _messenger,
    address _nilGasPriceOracle
  ) public initializer {
    // Validate input parameters
    if (_owner == address(0)) {
      revert ErrorInvalidOwner();
    }

    if (_defaultAdmin == address(0)) {
      revert ErrorInvalidDefaultAdmin();
    }

    if (_nilGasPriceOracle == address(0)) {
      revert ErrorInvalidNilGasPriceOracle();
    }
    L1BaseBridge.__L1BaseBridge_init(_owner, _defaultAdmin, _counterPartyETHBridge, _messenger, _nilGasPriceOracle);
  }

  /*//////////////////////////////////////////////////////////////////////////
                             PUBLIC MUTATING FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IL1ETHBridge
  function depositETH(
    address to,
    uint256 amount,
    address l2FeeRefundRecipient,
    uint256 gasLimit,
    uint256 userFeePerGas, // User-defined optional maxFeePerGas
    uint256 userMaxPriorityFeePerGas // User-defined optional maxPriorityFeePerGas
  ) external payable override {
    _deposit(to, amount, l2FeeRefundRecipient, new bytes(0), gasLimit, userFeePerGas, userMaxPriorityFeePerGas);
  }

  /// @inheritdoc IL1ETHBridge
  function depositETHAndCall(
    address to,
    uint256 amount,
    address l2FeeRefundRecipient,
    bytes memory data,
    uint256 gasLimit,
    uint256 userFeePerGas, // User-defined optional maxFeePerGas
    uint256 userMaxPriorityFeePerGas // User-defined optional maxPriorityFeePerGas
  ) external payable override {
    _deposit(to, amount, l2FeeRefundRecipient, data, gasLimit, userFeePerGas, userMaxPriorityFeePerGas);
  }

  /// @inheritdoc IL1Bridge
  function cancelDeposit(bytes32 messageHash) public override nonReentrant {
    address caller = _msgSender();

    // get DepositMessageDetails
    IL1BridgeMessenger.DepositMessage memory depositMessage = IL1BridgeMessenger(messenger).getDepositMessage(
      messageHash
    );

    // Decode the message to extract the token address and the original sender (_from)
    (, , address depositorAddress, , uint256 depositAmount, ) = abi.decode(
      depositMessage.message,
      (address, address, address, address, uint256, bytes)
    );

    if (caller != router && caller != depositorAddress) {
      revert UnAuthorizedCaller();
    }

    if (depositMessage.depositType != IL1BridgeMessenger.DepositType.ETH) {
      revert InvalidDepositType();
    }

    // L1BridgeMessenger to verify if the deposit can be cancelled
    IL1BridgeMessenger(messenger).cancelDeposit(messageHash);

    // Refund the deposited ETH to the refundAddress
    (bool success, ) = payable(depositMessage.l1DepositRefundAddress).call{ value: depositAmount }("");

    if (!success) {
      revert ErrorEthRefundFailed(messageHash);
    }

    emit DepositCancelled(messageHash, depositorAddress, depositAmount);
  }

  /// @inheritdoc IL1Bridge
  function claimFailedDeposit(bytes32 messageHash, bytes32[] memory claimProof) public override nonReentrant {
    IL1BridgeMessenger.DepositMessage memory depositMessage = IL1BridgeMessenger(messenger).getDepositMessage(
      messageHash
    );

    // Decode the message to extract the depositAmount
    (, , , , uint256 l1DepositAmount, ) = abi.decode(
      depositMessage.message,
      (address, address, address, address, uint256, bytes)
    );

    if (depositMessage.depositType != IL1BridgeMessenger.DepositType.ETH) {
      revert InvalidDepositType();
    }

    // L1BridgeMessenger to verify if the deposit can be claimed
    IL1BridgeMessenger(messenger).claimFailedDeposit(messageHash, claimProof);

    // Refund the deposited ETH to the refundAddress
    (bool success, ) = payable(depositMessage.l1DepositRefundAddress).call{ value: l1DepositAmount }("");

    if (!success) {
      revert ErrorEthRefundFailed(messageHash);
    }

    emit DepositClaimed(messageHash, address(0), depositMessage.l1DepositRefundAddress, l1DepositAmount);
  }

  /*//////////////////////////////////////////////////////////////////////////
                             INTERNAL-FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

  /// @dev The internal ETH deposit implementation.
  /// @param _l2DepositRecipient The recipient address on nil-chain.
  /// @param _depositAmount The amount of ETH to be deposited.
  /// @param _l2FeeRefundRecipient The address of recipient to receive the excess-fee refund on nil-chain
  /// @param _data Optional data to forward to recipient's account.
  /// @param _nilGasLimit Gas limit required to complete the deposit on nil-chain.
  /// @param _userMaxFeePerGas The maximum Fee per gas unit that the user is willing to pay.
  /// @param _userMaxPriorityFeePerGas The maximum priority fee per gas unit that the user is willing to pay.
  function _deposit(
    address _l2DepositRecipient,
    uint256 _depositAmount,
    address _l2FeeRefundRecipient,
    bytes memory _data,
    uint256 _nilGasLimit,
    uint256 _userMaxFeePerGas, // User-defined optional maxFeePerGas
    uint256 _userMaxPriorityFeePerGas // User-defined optional maxPriorityFeePerGas
  ) internal virtual nonReentrant {
    if (_l2DepositRecipient == address(0)) {
      revert ErrorInvalidL2Recipient();
    }

    if (_depositAmount == 0) {
      revert ErrorZeroEthDeposit();
    }

    if (_l2FeeRefundRecipient == address(0)) {
      revert ErrorInvalidL2FeeRefundRecipient();
    }

    if (_nilGasLimit == 0) {
      revert ErrorInvalidL2GasLimit();
    }

    address _depositorAddress = _msgSender();

    if (router == _msgSender()) {
      (_depositorAddress, _data) = abi.decode(_data, (address, bytes));
    }

    INilGasPriceOracle.FeeCreditData memory feeCreditData = INilGasPriceOracle(nilGasPriceOracle).computeFeeCredit(
      _nilGasLimit,
      _userMaxFeePerGas,
      _userMaxPriorityFeePerGas
    );

    if (msg.value < _depositAmount + feeCreditData.feeCredit) {
      revert ErrorInsufficientValueForFeeCredit();
    }

    feeCreditData.nilGasLimit = _nilGasLimit;

    // Generate message passed to L2ERC20Bridge
    bytes memory _message = abi.encodeCall(
      IL2ETHBridge.finalizeETHDeposit,
      (_depositorAddress, _l2DepositRecipient, _l2FeeRefundRecipient, _depositAmount, _data)
    );

    // Send message to L1BridgeMessenger.
    IL1BridgeMessenger(messenger).sendMessage{ value: msg.value }(
      IL1BridgeMessenger.DepositType.ETH,
      counterpartyBridge,
      _depositAmount,
      _message,
      _depositorAddress,
      feeCreditData
    );

    emit DepositETH(_depositorAddress, _l2DepositRecipient, _depositAmount, _data);
  }

  /// @inheritdoc IL1ETHBridge
  function decodeETHDepositMessage(bytes memory _message) public pure override returns (ETHDepositMessage memory) {
    // Validate that the first 4 bytes of the message match the function selector
    bytes4 selector;
    assembly {
      selector := mload(add(_message, 32))
    }
    if (selector != FINALIZE_DEPOSIT_ETH_SELECTOR) {
      revert ErrorInvalidFinalizeDepositFunctionSelector();
    }

    // Extract the data part of the message
    bytes memory messageData;
    assembly {
      let dataLength := sub(mload(_message), 4)
      messageData := mload(0x40)
      mstore(messageData, dataLength)
      mstore(0x40, add(messageData, add(dataLength, 32)))
      mstore(add(messageData, 32), mload(add(_message, 36)))
    }

    (
      address depositorAddress,
      address l2DepositRecipient,
      address l2FeeRefundRecipient,
      uint256 depositAmount,
      bytes memory data
    ) = abi.decode(messageData, (address, address, address, uint256, bytes));

    return
      ETHDepositMessage({
        depositorAddress: depositorAddress,
        l2DepositRecipient: l2DepositRecipient,
        l2FeeRefundRecipient: l2FeeRefundRecipient,
        depositAmount: depositAmount,
        recipientCallData: data
      });
  }
}
