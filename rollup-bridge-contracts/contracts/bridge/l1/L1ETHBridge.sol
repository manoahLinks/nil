// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { NilAccessControl } from "../../NilAccessControl.sol";
import { IL1ETHBridge } from "./interfaces/IL1ETHBridge.sol";
import { IL2ETHBridge } from "../l2/interfaces/IL2ETHBridge.sol";
import { IL1BridgeRouter } from "./interfaces/IL1BridgeRouter.sol";
import { IL1Bridge } from "./interfaces/IL1Bridge.sol";
import { IBridge } from "../interfaces/IBridge.sol";
import { IL1BridgeMessenger } from "./interfaces/IL1BridgeMessenger.sol";
import { INilGasPriceOracle } from "./interfaces/INilGasPriceOracle.sol";

/// @title L1ETHBridge
/// @notice The `L1ETHBridge` contract for ETH bridging from L1.
contract L1ETHBridge is
    OwnableUpgradeable,
    PausableUpgradeable,
    NilAccessControl,
    ReentrancyGuardUpgradeable,
    IL1ETHBridge
{
    /*//////////////////////////////////////////////////////////////////////////
                             ERRORS   
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Invalid owner address.
    error ErrorInvalidOwner();

    /// @dev Invalid default admin address.
    error ErrorInvalidDefaultAdmin();

    /// @dev Failed to refund ETH for the depositMessage
    error ErrorEthRefundFailed(bytes32 messageHash);

    /// @dev Error due to Zero eth-deposit
    error ErrorZeroEthDeposit();

    /// @dev Error due to invalid l2 feeRefund recipient address
    error ErrorInvalidL2FeeRefundRecipient();

    /// @dev Error due to invalid l2 recipient address
    error ErrorInvalidL2Recipient();

    /// @dev Error due to invalid L2 GasLimit
    error ErrorInvalidL2GasLimit();

    error ErrorInsufficientValueForFeeCredit();

    error ErrorInvalidNilGasPriceOracle();

    /*//////////////////////////////////////////////////////////////////////////
                             STATE-VARIABLES   
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IL1Bridge
    address public override router;

    /// @inheritdoc IL1Bridge
    address public override counterpartyBridge;

    /// @inheritdoc IL1Bridge
    address public override messenger;

    /// @inheritdoc IL1Bridge
    address public override nilGasPriceOracle;

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
    )
        external
        initializer
    {
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

        // Initialize the Ownable contract with the owner address
        OwnableUpgradeable.__Ownable_init(_owner);

        // Initialize the Pausable contract
        PausableUpgradeable.__Pausable_init();

        // Initialize the AccessControlEnumerable contract
        __AccessControlEnumerable_init();

        // Set role admins
        // The OWNER_ROLE is set as its own admin to ensure that only the current owner can manage this role.
        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);

        // The DEFAULT_ADMIN_ROLE is set as its own admin to ensure that only the current default admin can manage this
        // role.
        _setRoleAdmin(DEFAULT_ADMIN_ROLE, OWNER_ROLE);

        // Grant roles to defaultAdmin and owner
        // The DEFAULT_ADMIN_ROLE is granted to both the default admin and the owner to ensure that both have the
        // highest level of control.
        // The PROPOSER_ROLE_ADMIN is granted to both the default admin and the owner to allow them to manage proposers.
        // The OWNER_ROLE is granted to the owner to ensure they have the highest level of control over the contract.
        _grantRole(OWNER_ROLE, _owner);
        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);

        ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

        counterpartyBridge = _counterPartyETHBridge;
        messenger = _messenger;
        nilGasPriceOracle = _nilGasPriceOracle;
    }

    function setRouter(address _router) external override onlyOwner {
        router = _router;
    }

    function setMessenger(address _messenger) external override onlyOwner {
        messenger = _messenger;
    }

    function setNilGasPriceOracle(address _nilGasPriceOracle) external override onlyOwner {
        nilGasPriceOracle = _nilGasPriceOracle;
    }

    modifier onlyRouter() {
        require(msg.sender == router, "Caller is not the router");
        _;
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
    )
        external
        payable
        override
    {
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
    )
        external
        payable
        override
    {
        _deposit(to, amount, l2FeeRefundRecipient, data, gasLimit, userFeePerGas, userMaxPriorityFeePerGas);
    }

    /// @inheritdoc IL1Bridge
    function cancelDeposit(bytes32 messageHash) external payable override nonReentrant {
        address caller = _msgSender();

        // get DepositMessageDetails
        IL1BridgeMessenger.DepositMessage memory depositMessage =
            IL1BridgeMessenger(messenger).getDepositMessage(messageHash);

        // Decode the message to extract the token address and the original sender (_from)
        (,, address depositorAddress,, uint256 depositAmount,) =
            abi.decode(depositMessage.message, (address, address, address, address, uint256, bytes));

        if (caller != router && caller != depositorAddress) {
            revert UnAuthorizedCaller();
        }

        if (depositMessage.depositType != IL1BridgeMessenger.DepositType.ETH) {
            revert InvalidDepositType();
        }

        // L1BridgeMessenger to verify if the deposit can be cancelled
        IL1BridgeMessenger(messenger).cancelDeposit(messageHash);

        // Refund the deposited ETH to the refundAddress
        address refundAddress = depositMessage.refundAddress;
        (bool success,) = refundAddress.call{ value: depositAmount }("");

        if (!success) {
            revert ErrorEthRefundFailed(messageHash);
        }

        emit DepositCancelled(messageHash, depositorAddress, depositAmount);
    }

    /*//////////////////////////////////////////////////////////////////////////
                             INTERNAL-FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev The internal ETH deposit implementation.
    /// @param _to The recipient address on nil-chain.
    /// @param _amount The amount of ETH to be deposited.
    /// @param _l2FeeRefundRecipient The address of recipient to receive the excess-fee refund on nil-chain
    /// @param _data Optional data to forward to recipient's account.
    /// @param _l2GasLimit Gas limit required to complete the deposit on nil-chain.
    function _deposit(
        address _to,
        uint256 _amount,
        address _l2FeeRefundRecipient,
        bytes memory _data,
        uint256 _l2GasLimit,
        uint256 _userMaxFeePerGas, // User-defined optional maxFeePerGas
        uint256 _userMaxPriorityFeePerGas // User-defined optional maxPriorityFeePerGas
    )
        internal
        virtual
        nonReentrant
    {
        if (_to == address(0)) {
            revert ErrorInvalidL2Recipient();
        }

        if (_amount == 0) {
            revert ErrorZeroEthDeposit();
        }

        if (_l2FeeRefundRecipient == address(0)) {
            revert ErrorInvalidL2FeeRefundRecipient();
        }

        if (_l2GasLimit == 0) {
            revert ErrorInvalidL2GasLimit();
        }

        address _from = _msgSender();
        if (router == _from) {
            (_from, _data) = abi.decode(_data, (address, bytes));
        }

        INilGasPriceOracle.FeeCreditData memory feeCreditData = INilGasPriceOracle(nilGasPriceOracle).computeFeeCredit(
            _l2GasLimit, _userMaxFeePerGas, _userMaxPriorityFeePerGas
        );

        if (msg.value < _amount + feeCreditData.feeCredit) {
            revert ErrorInsufficientValueForFeeCredit();
        }

        // Generate message passed to L2ERC20Bridge
        bytes memory _message = abi.encodeCall(
            IL2ETHBridge.finalizeETHDeposit, (l2EthAddress, _from, _to, _l2FeeRefundRecipient, _amount, _data)
        );

        // Send message to L1BridgeMessenger.
        IL1BridgeMessenger(messenger).sendMessage{ value: msg.value }(
            IL1BridgeMessenger.DepositType.ETH, counterpartyBridge, _amount, _message, _l2GasLimit, _from, feeCreditData
        );

        emit DepositETH(l2EthAddress, _from, _to, _amount, _data);
    }

    /*//////////////////////////////////////////////////////////////////////////
                             RESTRICTED FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridge
    function setPause(bool statusValue) external onlyOwner {
        if (statusValue) {
            _pause();
        } else {
            _unpause();
        }
    }

    /// @inheritdoc IBridge
    function transferOwnershipRole(address newOwner) external override onlyOwner {
        _revokeRole(OWNER_ROLE, owner());
        super.transferOwnership(newOwner);
        _grantRole(OWNER_ROLE, newOwner);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IL1Bridge).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
