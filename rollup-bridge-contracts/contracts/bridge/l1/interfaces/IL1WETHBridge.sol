// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IL1Bridge } from "./IL1Bridge.sol";

interface IL1WETHBridge is IL1Bridge {
    /*//////////////////////////////////////////////////////////////////////////
                             ERRORS   
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Invalid WETH token address.
    error ErrorInvalidWethToken();

    /// @dev Invalid nil-chain WETH token address.
    error ErrorInvalidNilWethToken();

    /*//////////////////////////////////////////////////////////////////////////
                             EVENTS   
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted upon deposit of ERC20Token from layer-1 to nil-chain.
    /// @param l1Token The address of the token in layer-1.
    /// @param l2Token The address of the token in nil-chain.
    /// @param from The address of sender in layer-1.
    /// @param to The address of recipient in nil-chain.
    /// @param amount The amount of token will be deposited from layer-1 to nil-chain.
    /// @param data The optional calldata passed to recipient in nil-chain.
    event DepositWETH(
        address indexed l1Token, address indexed l2Token, address indexed from, address to, uint256 amount, bytes data
    );

    /**
     * @notice Emitted when a deposit is cancelled.
     * @param messageHash The hash of the cancelled deposit message.
     * @param l1Token The address of the L1 token involved in the deposit.
     * @param cancelledDepositRecipient The address of the recipient whose deposit was cancelled.
     * @param amount The amount of tokens that were to be deposited.
     */
    event DepositCancelled(
        bytes32 indexed messageHash, address indexed l1Token, address indexed cancelledDepositRecipient, uint256 amount
    );

    /*//////////////////////////////////////////////////////////////////////////
                             PUBLIC CONSTANT FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the address of the WETH token.
     * @return The address of the WETH token.
     */
    function wethToken() external view returns (address);

    /**
     * @notice Returns the address of the nil-chain WETH token.
     * @return The address of the nil-chain WETH token.
     */
    function nilWethToken() external view returns (address);

    /*//////////////////////////////////////////////////////////////////////////
                             RESTRICTED FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the address of the nil-chain WETH token.
     * @param _nilWethToken The new address of the nil-chain WETH token.
     */
    function setNilWethToken(address _nilWethToken) external;

    /*//////////////////////////////////////////////////////////////////////////
                             PUBLIC MUTATING FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Initiates the deposit of WETH tokens to the nil-chain for a specified recipient.
     * @param l2DepositRecipient The recipient address to receive the token on the nil-chain.
     * @param depositAmount The amount of tokens to deposit.
     * @param l2FeeRefundRecipient The recipient address to receive the refund of excess fee on the nil-chain.
     * @param l2GasLimit The gas limit required to complete the deposit on the nil-chain.
     * @param userFeePerGas The fee per gas unit that the user is willing to pay.
     * @param userMaxPriorityFeePerGas The maximum priority fee per gas unit that the user is willing to pay.
     */
    function depositWETH(
        address l2DepositRecipient,
        uint256 depositAmount,
        address l2FeeRefundRecipient,
        uint256 l2GasLimit,
        uint256 userFeePerGas,
        uint256 userMaxPriorityFeePerGas
    )
        external
        payable;

    /**
     * @notice Deposits WETH tokens to the nil-chain for a specified recipient and calls a function on the recipient's
     * contract.
     * @param l2DepositRecipient The recipient address to receive the token on the nil-chain.
     * @param depositAmount The amount of tokens to deposit.
     * @param l2FeeRefundRecipient The recipient address to receive the refund of excess fee on the nil-chain.
     * @param data Optional data to forward to the recipient's account.
     * @param l2GasLimit The gas limit required to complete the deposit on the nil-chain.
     * @param userFeePerGas The fee per gas unit that the user is willing to pay.
     * @param userMaxPriorityFeePerGas The maximum priority fee per gas unit that the user is willing to pay.
     */
    function depositWETHAndCall(
        address l2DepositRecipient,
        uint256 depositAmount,
        address l2FeeRefundRecipient,
        bytes memory data,
        uint256 l2GasLimit,
        uint256 userFeePerGas,
        uint256 userMaxPriorityFeePerGas
    )
        external
        payable;
}
