// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { IL1ERC20Bridge } from "./interfaces/IL1ERC20Bridge.sol";
import { IL1BridgeRouter } from "./interfaces/IL1BridgeRouter.sol";
import { IL1BridgeMessenger } from "./interfaces/IL1BridgeMessenger.sol";

/// @title L1BridgeRouter
/// @notice The `L1BridgeRouter` is the main entry for depositing ERC20 tokens.
/// All deposited tokens are routed to corresponding gateways.
/// @dev use this contract to query L1/L2 token address mapping.
contract L1BridgeRouter is OwnableUpgradeable, IL1BridgeRouter {
    using SafeTransferLib for ERC20;

    /*//////////////////////////////////////////////////////////////////////////
                             STATE-VARIABLES   
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice The addess of L1ERC20Bridge
    address public l1ERC20Bridge;

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
    /// @param _l1BridgeMessenger The address of l1BridgeMessenger contract.
    function initialize(address _owner, address _l1ERC20Bridge, address _l1BridgeMessenger) external initializer {
        OwnableUpgradeable.__Ownable_init(_owner);
        l1ERC20Bridge = _l1ERC20Bridge;
        l1BridgeMessenger = IL1BridgeMessenger(_l1BridgeMessenger);
        emit L1ERC20BridgeSet(address(0), _l1ERC20Bridge);
        emit L1BridgeMessengerSet(address(0), address(_l1BridgeMessenger));
    }

    /*//////////////////////////////////////////////////////////////////////////
                           USER-FACING CONSTANT FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IL1BridgeRouter
    function getL2ERC20Address(address _l1TokenAddress) external view override returns (address) {
        address _erc20bridgeAddress = getERC20Bridge(_l1TokenAddress);
        if (_erc20bridgeAddress == address(0)) {
            return address(0);
        }

        return IL1ERC20Bridge(_erc20bridgeAddress).getL2ERC20Address(_l1TokenAddress);
    }

    /// @inheritdoc IL1BridgeRouter
    function getERC20Bridge(address _token) public view returns (address) {
        return l1ERC20Bridge;
    }

    /*//////////////////////////////////////////////////////////////////////////
                           BRIDGE-SPECIFIC MUTATION FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IL1BridgeRouter
    /// @dev All bridge contracts must have reentrancy guard to prevent potential attack though this function.
    function pullERC20(address _sender, address _token, uint256 _amount) external onlyInContext returns (uint256) {
        address _caller = _msgSender();
        uint256 _balance = ERC20(_token).balanceOf(_caller);
        ERC20(_token).safeTransferFrom(_sender, _caller, _amount);
        _amount = ERC20(_token).balanceOf(_caller) - _balance;
        return _amount;
    }

    /*//////////////////////////////////////////////////////////////////////////
                           USER-SPECIFIC MUTATION FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IL1ERC20Bridge
    function depositERC20(address _token, uint256 _amount, uint256 _gasLimit) external payable override {
        depositERC20AndCall(_token, _msgSender(), _amount, new bytes(0), _gasLimit);
    }

    /// @inheritdoc IL1ERC20Bridge
    function depositERC20(address _token, address _to, uint256 _amount, uint256 _gasLimit) external payable override {
        depositERC20AndCall(_token, _to, _amount, new bytes(0), _gasLimit);
    }

    /// @inheritdoc IL1ERC20Bridge
    function depositERC20AndCall(
        address _token,
        address _to,
        uint256 _amount,
        bytes memory _data,
        uint256 _gasLimit
    )
        public
        payable
        override
        onlyNotInContext
    {
        require(l1ERC20Bridge != address(0), "l1ERC20Bridge not initialized");

        // enter deposit context
        l1BridgeInContext = l1ERC20Bridge;

        // encode msg.sender with _data
        bytes memory _routerData = abi.encode(_msgSender(), _data);

        IL1ERC20Bridge(l1ERC20Bridge).depositERC20AndCall{ value: msg.value }(
            _token, _to, _amount, _routerData, _gasLimit
        );

        // leave deposit context
        l1BridgeInContext = address(0);
    }

    function cancelDeposit(bytes32 messageHash) external payable {
        // Get the deposit message from the messenger
        IL1BridgeMessenger.DepositType depositType = l1BridgeMessenger.getDepositType(messageHash);

        // Route the cancellation request based on the deposit type
        if (depositType == IL1BridgeMessenger.DepositType.ERC20) {
            IL1ERC20Bridge(l1ERC20Bridge).cancelDeposit(messageHash);
        } else {
            revert("Unknown deposit type");
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
}
