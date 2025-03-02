// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { NilAccessControl } from "../../NilAccessControl.sol";
import { IL1WETHBridge } from "./interfaces/IL1WETHBridge.sol";
import { IL2WETHBridge } from "../l2/interfaces/IL2WETHBridge.sol";
import { IL1BridgeRouter } from "./interfaces/IL1BridgeRouter.sol";
import { IL1Bridge } from "./interfaces/IL1Bridge.sol";
import { IBridge } from "../interfaces/IBridge.sol";
import { IL1BridgeMessenger } from "./interfaces/IL1BridgeMessenger.sol";
import { INilGasPriceOracle } from "./interfaces/INilGasPriceOracle.sol";
import { L1BaseBridge } from "./L1BaseBridge.sol";

/// @title L1WETHBridge
/// @notice The `L1WETHBridge` contract for WETHBridging in L1.
contract L1WETHBridge is L1BaseBridge, IL1WETHBridge {
  using SafeTransferLib for ERC20;

  /*//////////////////////////////////////////////////////////////////////////
                             STATE-VARIABLES   
    //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IL1WETHBridge
  address public override wethToken;

  /// @inheritdoc IL1WETHBridge
  address public override nilWethToken;

  /// @dev The storage slots for future usage.
  uint256[50] private __gap;

  /*//////////////////////////////////////////////////////////////////////////
                             CONSTRUCTOR   
    //////////////////////////////////////////////////////////////////////////*/

  /// @notice Constructor for `L1WETHBridge` implementation contract.
  constructor() {
    _disableInitializers();
  }

  /// @notice Initialize the storage of L1WETHBridge.
  /// @param _owner The owner of L1WETHBridge
  /// @param _counterPartyWETHBridge The address of WETHBridge on nil-chain
  /// @param _messenger The address of BridgeMessenger in layer-1.
  function initialize(
    address _owner,
    address _defaultAdmin,
    address _wethToken,
    address _nilWethToken,
    address _counterPartyWETHBridge,
    address _messenger,
    address _nilGasPriceOracle
  ) external initializer {
    // Validate input parameters
    if (_owner == address(0)) {
      revert ErrorInvalidOwner();
    }

    if (_defaultAdmin == address(0)) {
      revert ErrorInvalidDefaultAdmin();
    }

    if (_wethToken == address(0)) {
      revert ErrorInvalidWethToken();
    }

    if (_nilWethToken == address(0)) {
      revert ErrorInvalidNilWethToken();
    }

    if (_counterPartyWETHBridge == address(0)) {
      revert ErrorInvalidCounterpartyBridge();
    }

    if (_messenger == address(0)) {
      revert ErrorInvalidMessenger();
    }

    if (_nilGasPriceOracle == address(0)) {
      revert ErrorInvalidNilGasPriceOracle();
    }

    L1BaseBridge.__L1BaseBridge_init(_owner, _defaultAdmin, _counterPartyWETHBridge, _messenger, _nilGasPriceOracle);

    wethToken = _wethToken;
    nilWethToken = _nilWethToken;
  }

  /// @inheritdoc IL1WETHBridge
  function setNilWethToken(address _nilWethToken) external override onlyAdmin {
    nilWethToken = _nilWethToken;
  }

  /*//////////////////////////////////////////////////////////////////////////
                             PUBLIC MUTATING FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IL1WETHBridge
  function depositWETH(
    address l2DepositRecipient,
    uint256 depositAmount,
    address l2FeeRefundRecipient,
    uint256 nilGasLimit,
    uint256 userMaxFeePerGas,
    uint256 userMaxPriorityFeePerGas
  ) external payable override {
    if (l2DepositRecipient == address(0)) {
      revert ErrorInvalidL2DepositRecipient();
    }

    if (depositAmount == 0) {
      revert ErrorEmptyDeposit();
    }

    if (l2FeeRefundRecipient == address(0)) {
      revert ErrorInvalidL2FeeRefundRecipient();
    }

    if (nilGasLimit == 0) {
      revert ErrorInvalidNilGasLimit();
    }

    _deposit(
      l2DepositRecipient,
      depositAmount,
      l2FeeRefundRecipient,
      new bytes(0),
      nilGasLimit,
      userMaxFeePerGas,
      userMaxPriorityFeePerGas
    );
  }

  /// @inheritdoc IL1WETHBridge
  function depositWETHAndCall(
    address l2DepositRecipient,
    uint256 depositAmount,
    address l2FeeRefundRecipient,
    bytes memory data,
    uint256 nilGasLimit,
    uint256 userMaxFeePerGas,
    uint256 userMaxPriorityFeePerGas
  ) external payable override {
    if (l2DepositRecipient == address(0)) {
      revert ErrorInvalidL2DepositRecipient();
    }

    if (depositAmount == 0) {
      revert ErrorEmptyDeposit();
    }

    if (l2FeeRefundRecipient == address(0)) {
      revert ErrorInvalidL2FeeRefundRecipient();
    }

    if (nilGasLimit == 0) {
      revert ErrorInvalidNilGasLimit();
    }

    _deposit(
      l2DepositRecipient,
      depositAmount,
      l2FeeRefundRecipient,
      data,
      nilGasLimit,
      userMaxFeePerGas,
      userMaxPriorityFeePerGas
    );
  }

  /// @inheritdoc IL1Bridge
  function cancelDeposit(bytes32 messageHash) external payable override nonReentrant {
    address caller = _msgSender();

    // get DepositMessageDetails
    IL1BridgeMessenger.DepositMessage memory depositMessage = IL1BridgeMessenger(messenger).getDepositMessage(
      messageHash
    );

    // Decode the message to extract the token address and the original sender (_from)
    (address l1TokenAddress, , address depositorAddress, , uint256 l1TokenAmount, ) = abi.decode(
      depositMessage.message,
      (address, address, address, address, uint256, bytes)
    );

    if (caller != router && caller != depositorAddress) {
      revert UnAuthorizedCaller();
    }

    if (depositMessage.depositType != IL1BridgeMessenger.DepositType.WETH) {
      revert InvalidDepositType();
    }

    // L1BridgeMessenger to verify if the deposit can be cancelled
    IL1BridgeMessenger(messenger).cancelDeposit(messageHash);

    // refund the deposited ERC20 tokens to the depositor
    ERC20(l1TokenAddress).safeTransfer(depositorAddress, l1TokenAmount);

    emit DepositCancelled(messageHash, l1TokenAddress, depositorAddress, l1TokenAmount);
  }

  /*//////////////////////////////////////////////////////////////////////////
                             INTERNAL-FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

  /// @dev Internal function to transfer WETH token to this contract.
  /// @param _depositAmount The amount of token to transfer.
  /// @param _encodedWETHTransferData The data passed by router or the bridge.
  /// @dev when depositor calls router, then _encodedWETHTransferData will contain the econdoed bytes of
  /// depositorAddress and calldata for the l2 target address
  /// @dev when depositor calls WETHBridge, then _encodedWETHTransferData will contain calldata for the l2 target
  /// address
  function _transferWETHIn(
    uint256 _depositAmount,
    bytes memory _encodedWETHTransferData
  ) internal returns (address, uint256, bytes memory) {
    // If the depositor called depositWETH via L1BridgeRouter, then _sender will be the l1BridgeRouter-address
    // If the depositor called depositWETH directly on L1WETHBridge, then _sender will be the l1WETHBridge-address
    address _sender = _msgSender();

    // retain the depositor address
    address _depositor = _sender;

    // initialize _data to hold the Optional data to forward to recipient's account.
    bytes memory _data = _encodedWETHTransferData;

    if (router == _sender) {
      // as the depositor called depositWETH function via L1BridgeRouter, extract the depositor-address from the
      // _data AKA routerData
      // _data is the data to be sent on the target address on nil-chain
      (_depositor, _data) = abi.decode(_encodedWETHTransferData, (address, bytes));

      // _depositor will be derived from the routerData as the depositor called on router directly
      // _sender will be router-address and its router's responsibility to pull the wethTokens from depositor to
      // WethBridge
      IL1BridgeRouter(router).pullERC20(_depositor, wethToken, _depositAmount);
    } else {
      // WETHBridge to transfer WETH tokens from depositor address to the WETHBridgeAddress
      // WETHBridge must have sufficient approval of spending on WETHAddress
      ERC20(wethToken).safeTransferFrom(_depositor, address(this), _depositAmount);
    }

    return (_depositor, _depositAmount, _data);
  }

  /// @dev Internal function to do all the deposit operations.
  /// @param _l2DepositRecipient The recipient address to recieve the token in L2.
  /// @param _depositAmount The amount of token to deposit.
  /// @param _data Optional data to forward to recipient's account.
  /// @param _l2FeeRefundRecipient the address of recipient for excess fee refund on L2.
  /// @param _nilGasLimit Gas limit required to complete the deposit on L2.
  /// @param _userMaxFeePerGas The maximum Fee per gas unit that the user is willing to pay.
  /// @param _userMaxPriorityFeePerGas The maximum priority fee per gas unit that the user is willing to pay.

  function _deposit(
    address _l2DepositRecipient,
    uint256 _depositAmount,
    address _l2FeeRefundRecipient,
    bytes memory _data,
    uint256 _nilGasLimit,
    uint256 _userMaxFeePerGas,
    uint256 _userMaxPriorityFeePerGas
  ) internal virtual nonReentrant {
    if (_depositAmount == 0) {
      revert ErrorEmptyDeposit();
    }

    // Transfer token into Bridge contract
    (address _depositor, , ) = _transferWETHIn(_depositAmount, _data);

    INilGasPriceOracle.FeeCreditData memory feeCreditData = INilGasPriceOracle(nilGasPriceOracle).computeFeeCredit(
      _nilGasLimit,
      _userMaxFeePerGas,
      _userMaxPriorityFeePerGas
    );

    if (msg.value < feeCreditData.feeCredit) {
      revert ErrorInsufficientValueForFeeCredit();
    }

    // Generate message passed to L2ERC20Bridge
    bytes memory _message = abi.encodeCall(
      IL2WETHBridge.finalizeDepositWETH,
      (wethToken, nilWethToken, _depositor, _l2DepositRecipient, _l2FeeRefundRecipient, _depositAmount, _data)
    );

    // Send message to L1BridgeMessenger.
    IL1BridgeMessenger(messenger).sendMessage{ value: msg.value }(
      IL1BridgeMessenger.DepositType.WETH,
      counterpartyBridge, // target-contract for the message
      0, // message value
      _message, // message
      _nilGasLimit, // gasLimit for execution of message on nil-chain
      _depositor,
      feeCreditData
    );

    emit DepositWETH(wethToken, nilWethToken, _depositor, _l2DepositRecipient, _depositAmount, _data);
  }
}
