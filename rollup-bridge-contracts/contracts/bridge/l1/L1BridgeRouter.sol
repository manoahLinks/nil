// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { NilAccessControl } from "../../NilAccessControl.sol";
import { NilRoleConstants } from "../../libraries/NilRoleConstants.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { IL1ERC20Bridge } from "./interfaces/IL1ERC20Bridge.sol";
import { IL1ETHBridge } from "./interfaces/IL1ETHBridge.sol";
import {IL1WETHBridge} from "./interfaces/IL1WETHBridge.sol";
import { IL1BridgeRouter } from "./interfaces/IL1BridgeRouter.sol";
import { IL1BridgeMessenger } from "./interfaces/IL1BridgeMessenger.sol";

/// @title L1BridgeRouter
/// @notice The `L1BridgeRouter` is the main entry for depositing ERC20 tokens.
/// All deposited tokens are routed to corresponding gateways.
/// @dev use this contract to query L1/L2 token address mapping.
contract L1BridgeRouter is
    OwnableUpgradeable,
    PausableUpgradeable,
    NilAccessControl,
    ReentrancyGuardUpgradeable,
    IL1BridgeRouter
{
    using SafeTransferLib for ERC20;

    /*//////////////////////////////////////////////////////////////////////////
                             STATE-VARIABLES   
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice The addess of L1ERC20Bridge
    address public override l1ERC20Bridge;

    /// @notice The address of L1EthBridge
    address public override l1ETHBridge;

    /// @notice The address of L1WETHBridge
    address public override l1WETHBridge;

    /// @notice The address of the L1WETH contract.
    address public override l1WETHAddress;

    /// @notice The address of the L2WETH token.
    address public override l2WETHTokenAddress;

    /// @notice The addess of L1BridgeMessenger
    IL1BridgeMessenger public l1BridgeMessenger;

    /// @notice The address of l1Bridge in current execution context.
    address transient public l1BridgeInContext;

    /*//////////////////////////////////////////////////////////////////////////
                             FUNCTION-MODIFIERS   
    //////////////////////////////////////////////////////////////////////////*/

    modifier onlyNotInContext() {
        require(l1BridgeInContext == address(0), "Only not in context");
        _;
    }

    modifier onlyInContext() {
        require(_msgSender() == l1BridgeInContext, "Only in deposit context");
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                             CONSTRUCTOR   
    //////////////////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    /*//////////////////////////////////////////////////////////////////////////
                             INITIALIZER   
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Initialize the storage of L1BridgeRouter.
    /// @param _l1ERC20Bridge The address of l1ERC20Bridge contract.
    /// @param _l1ETHBridge The address of l1ETHBridge contract.
    /// @param _l1BridgeMessenger The address of l1BridgeMessenger contract.
    function initialize(
        address _owner,
        address _defaultAdmin,
        address _l1ERC20Bridge,
        address _l1ETHBridge,
        address _l1WETHBridge,
        address _l1BridgeMessenger,
        address _l1WETHAddress,
        address _l2WETHTokenAddress
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

        l1ERC20Bridge = _l1ERC20Bridge;
        l1ETHBridge = _l1ETHBridge;
        l1WETHBridge = _l1WETHBridge;
        l1BridgeMessenger = IL1BridgeMessenger(_l1BridgeMessenger);
        l1WETHAddress = _l1WETHAddress;
        l2WETHTokenAddress = _l2WETHTokenAddress;
        emit L1ERC20BridgeSet(address(0), _l1ERC20Bridge);
        emit L1ETHBridgeSet(address(0), _l1ETHBridge);
        emit L1WETHBridgeSet(address(0), _l1WETHBridge);
        emit L1BridgeMessengerSet(address(0), address(_l1BridgeMessenger));
    }

    /*//////////////////////////////////////////////////////////////////////////
                           USER-FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IL1BridgeRouter
    function getL2TokenAddress(address _l1TokenAddress) external view override returns (address) {
        return IL1ERC20Bridge(l1ERC20Bridge).getL2TokenAddress(_l1TokenAddress);
    }

    /*//////////////////////////////////////////////////////////////////////////
                           BRIDGE-SPECIFIC MUTATION FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IL1BridgeRouter
    function pullERC20(address sender, address token, uint256 amount) external onlyInContext returns (uint256) {
        address _bridgeAddress = _msgSender();

        // Validate that the caller is one of the authorized bridges
        if (_bridgeAddress != address(l1ERC20Bridge) && _bridgeAddress != address(l1WETHBridge)) {
            revert ErrorUnauthorizedCaller();
        }

        // Get the current balance of the bridge contract
        uint256 _balance = ERC20(token).balanceOf(_bridgeAddress);

        // Transfer tokens from the sender to the bridge contract
        ERC20(token).safeTransferFrom(sender, _bridgeAddress, amount);

        // Calculate the actual amount of tokens pulled
        uint256 _amountPulled = ERC20(token).balanceOf(_bridgeAddress) - _balance;

        // Ensure the pulled amount matches the requested amount
        if (_amountPulled != amount) {
            revert ErrorERC20PullFailed();
        }

        return _amountPulled;
    }

    /*//////////////////////////////////////////////////////////////////////////
                           USER-SPECIFIC MUTATION FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IL1BridgeRouter
    function depositERC20(address token, address l2DepositRecipient, uint256 depositAmount, address l2FeeRefundRecipient, uint256 nilGasLimit, uint256 userFeePerGas, uint256 userMaxPriorityFeePerGas) external payable override {
        depositERC20AndCall(token, l2DepositRecipient, depositAmount, l2FeeRefundRecipient, new bytes(0), nilGasLimit, userFeePerGas, userMaxPriorityFeePerGas);
    }

    /// @inheritdoc IL1BridgeRouter
    function depositERC20AndCall(
        address token,
        address l2DepositRecipient,
        uint256 depositAmount,
        address l2FeeRefundRecipient,
        bytes memory data,
        uint256 nilGasLimit,
        uint256 userFeePerGas, // User-defined optional maxFeePerGas
        uint256 userMaxPriorityFeePerGas // User-defined optional maxPriorityFeePerGas
    )
        public
        payable
        override
        onlyNotInContext
    {
        if(token == address(0)) {
          revert ErrorInvalidTokenAddress();
        }

        if(l1ERC20Bridge == address(0)) {
          revert ErrorInvalidL1ERC20BridgeAddress();
        }

        if(depositAmount == 0) {
          revert ErrorEmptyDeposit();
        }

        if(nilGasLimit == 0) {
          revert ErrorInvalidNilGasLimit();
        }

        // enter deposit context
        l1BridgeInContext = l1ERC20Bridge;

        // encode msg.sender with _data
        bytes memory routerData = abi.encode(_msgSender(), data);

        IL1ERC20Bridge(l1ERC20Bridge).depositERC20AndCall{ value: msg.value }(
            token, l2DepositRecipient, depositAmount, l2FeeRefundRecipient, routerData, nilGasLimit, userFeePerGas, userMaxPriorityFeePerGas
        );

        // leave deposit context
        l1BridgeInContext = address(0);
    }


    /// @inheritdoc IL1BridgeRouter
    function depositWETH(address l2DepositRecipient, uint256 depositAmount, address l2FeeRefundRecipient, uint256 gasLimit, uint256 userFeePerGas, uint256 userMaxPriorityFeePerGas) external payable override {
        depositWETHAndCall(l2DepositRecipient, depositAmount, l2FeeRefundRecipient, new bytes(0), gasLimit, userFeePerGas, userMaxPriorityFeePerGas);
    }

    /// @inheritdoc IL1BridgeRouter
    function depositWETHAndCall(
        address l2DepositRecipient,
        uint256 depositAmount,
        address l2FeeRefundRecipient,
        bytes memory data,
        uint256 nilGasLimit,
        uint256 userFeePerGas, // User-defined optional maxFeePerGas
        uint256 userMaxPriorityFeePerGas // User-defined optional maxPriorityFeePerGas
    )
        public
        payable
        override
        onlyNotInContext
    {
        if(l1WETHBridge == address(0)) {
          revert ErrorInvalidL1WETHBridgeAddress();
        }

        if(l2DepositRecipient == address(0)) {
          revert ErrorInvalidL2DepositRecipient();
        }

        if(depositAmount == 0) {
          revert ErrorEmptyDeposit();
        }

        if(l2FeeRefundRecipient == address(0)) {
          revert ErrorInvalidL2FeeRefundRecipient();
        }

        if(nilGasLimit == 0) {
          revert ErrorInvalidNilGasLimit();
        }

        // enter deposit context
        l1BridgeInContext = l1WETHBridge;

        // encode msg.sender with _data
        bytes memory routerData = abi.encode(_msgSender(), data);

        IL1WETHBridge(l1WETHBridge).depositWETHAndCall{ value: msg.value }(
            l2DepositRecipient, depositAmount, l2FeeRefundRecipient, routerData, nilGasLimit, userFeePerGas, userMaxPriorityFeePerGas
        );

        // leave deposit context
        l1BridgeInContext = address(0);
    }

    /// @inheritdoc IL1BridgeRouter
    function depositETH(address to, uint256 amount, address l2FeeRefundRecipient, uint256 gasLimit, uint256 userFeePerGas, uint256 userMaxFeePerGas) external payable override {
        depositETHAndCall(to, amount, l2FeeRefundRecipient, new bytes(0), gasLimit, userFeePerGas, userMaxFeePerGas);
    }

    /// @inheritdoc IL1BridgeRouter
    function depositETHAndCall(
        address l2DepositRecipient,
        uint256 depositAmount,
        address l2FeeRefundRecipient,
        bytes memory data,
        uint256 nilGasLimit,
        uint256 userFeePerGas, // User-defined optional maxFeePerGas
        uint256 userMaxPriorityFeePerGas // User-defined optional maxPriorityFeePerGas
    )
        public
        payable
        override
        onlyNotInContext
    {
        if(l1ETHBridge == address(0)) {
          revert ErrorInvalidL1ETHBridgeAddress();
        }

        if(l2DepositRecipient == address(0)) {
          revert ErrorInvalidL2DepositRecipient();
        }

        if(depositAmount == 0) {
          revert ErrorEmptyDeposit();
        }

        if(l2FeeRefundRecipient == address(0)) {
          revert ErrorInvalidL2FeeRefundRecipient();
        }

        if(nilGasLimit == 0) {
          revert ErrorInvalidNilGasLimit();
        }

        // enter deposit context
        l1BridgeInContext = l1ETHBridge;

        // encode msg.sender with _data
        bytes memory routerData = abi.encode(_msgSender(), data);

        IL1ETHBridge(l1ETHBridge).depositETHAndCall{ value: msg.value }(
            l2DepositRecipient, depositAmount, l2FeeRefundRecipient, routerData, nilGasLimit, userFeePerGas, userMaxPriorityFeePerGas
        );

        // leave deposit context
        l1BridgeInContext = address(0);
    }

    /// @inheritdoc IL1BridgeRouter
    function cancelDeposit(bytes32 messageHash) external payable {
        // Get the deposit message from the messenger
        IL1BridgeMessenger.DepositType depositType = l1BridgeMessenger.getDepositType(messageHash);

        // Route the cancellation request based on the deposit type
        if (depositType == IL1BridgeMessenger.DepositType.ERC20) {
            IL1ERC20Bridge(l1ERC20Bridge).cancelDeposit(messageHash);
        } else if (depositType == IL1BridgeMessenger.DepositType.ETH) {
            IL1ETHBridge(l1ERC20Bridge).cancelDeposit(messageHash);
        } else if (depositType == IL1BridgeMessenger.DepositType.WETH) {
            IL1WETHBridge(l1WETHBridge).cancelDeposit(messageHash);
        } else {
            revert ErrorInvalidDepositType();
        }
    }

    /// @inheritdoc IL1BridgeRouter
    function claimFailedDeposit(bytes32 messageHash, bytes32[] memory claimProof) external override {
        // Get the deposit message from the messenger
        IL1BridgeMessenger.DepositType depositType = l1BridgeMessenger.getDepositType(messageHash);

        // Route the cancellation request based on the deposit type
        if (depositType == IL1BridgeMessenger.DepositType.ERC20) {
            IL1ERC20Bridge(l1ERC20Bridge).claimFailedDeposit(messageHash, claimProof);
        } else if (depositType == IL1BridgeMessenger.DepositType.ETH) {
            IL1ETHBridge(l1ERC20Bridge).claimFailedDeposit(messageHash, claimProof);
        } else if (depositType == IL1BridgeMessenger.DepositType.WETH) {
            IL1WETHBridge(l1WETHBridge).claimFailedDeposit(messageHash, claimProof);
        } else {
            revert ErrorInvalidDepositType();
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                           RESTRICTED FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

  /// @inheritdoc IL1BridgeRouter
  function setL1ERC20Bridge(address _newERC20Bridge) external onlyOwner {
      address _oldERC20Bridge = l1ERC20Bridge;
      l1ERC20Bridge = _newERC20Bridge;

      emit L1ERC20BridgeSet(_oldERC20Bridge, _newERC20Bridge);
  }

  /// @inheritdoc IL1BridgeRouter
  function setL1ETHBridge(address newL1ETHBridge) external onlyOwner {
      address oldL1ETHBridge = l1ETHBridge;
      l1ETHBridge = newL1ETHBridge;

      emit L1ETHBridgeSet(oldL1ETHBridge, newL1ETHBridge);
  }

  /// @inheritdoc IL1BridgeRouter
  function setL1WETHBridge(address newL1WETHBridge) external onlyOwner {
      address oldL1WETHBridge = l1WETHBridge;
      l1WETHBridge = newL1WETHBridge;

      emit L1WETHBridgeSet(oldL1WETHBridge, newL1WETHBridge);
  }

  /// @inheritdoc IL1BridgeRouter
  function setPause(bool _status) external onlyOwner {
    if (_status) {
      _pause();
    } else {
      _unpause();
    }
  }

  /// @inheritdoc IL1BridgeRouter
  function transferOwnershipRole(address newOwner) external override onlyOwner {
    _revokeRole(NilRoleConstants.OWNER_ROLE, owner());
    super.transferOwnership(newOwner);
    _grantRole(NilRoleConstants.OWNER_ROLE, newOwner);
  }
}
