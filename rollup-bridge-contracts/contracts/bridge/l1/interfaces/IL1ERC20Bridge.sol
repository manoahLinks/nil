// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IL1Bridge } from "./IL1Bridge.sol";

interface IL1ERC20Bridge is IL1Bridge {
    /*//////////////////////////////////////////////////////////////////////////
                             EVENTS   
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when token mapping for ERC20 token is updated.
    /// @param l1Token The address of ERC20 token in layer-1.
    /// @param oldL2Token The address of the old ERC20Token-Address in nil-chain.
    /// @param newL2Token The address of the new ERC20Token-Address in nil-chain.
    event UpdateTokenMapping(address indexed l1Token, address indexed oldL2Token, address indexed newL2Token);

    /// @notice Emitted upon deposit of ERC20Token from layer-1 to nil-chain.
    /// @param l1Token The address of the token in layer-1.
    /// @param l2Token The address of the token in nil-chain.
    /// @param from The address of sender in layer-1.
    /// @param to The address of recipient in nil-chain.
    /// @param amount The amount of token will be deposited from layer-1 to nil-chain.
    /// @param data The optional calldata passed to recipient in nil-chain.
    event DepositERC20(
        address indexed l1Token, address indexed l2Token, address indexed from, address to, uint256 amount, bytes data
    );

    event DepositCancelled(
        bytes32 indexed messageHash, address indexed l1Token, address indexed cancelledDepositRecipient, uint256 amount
    );

    /*//////////////////////////////////////////////////////////////////////////
                             PUBLIC CONSTANT FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

    function getL2ERC20Address(address l1TokenAddress) external view returns (address);

    /*//////////////////////////////////////////////////////////////////////////
                             PUBLIC MUTATING FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits ERC20 tokens to the nil-chain.
     * @param _token The address of the ERC20 token to deposit.
     * @param _amount The amount of tokens to deposit.
     * @param _gasLimit The gas limit required to complete the deposit on nil-chain.
     */
    function depositERC20(address _token, uint256 _amount, uint256 _gasLimit) external payable;

    /**
     * @notice Initiates the ERC20 tokens to the nil-chain. for a specified recipient.
     * @param _token The address of the ERC20 in L1 token to deposit.
     * @param _to The recipient address to receive the token in nil-chain.
     * @param _amount The amount of tokens to deposit.
     * @param _gasLimit The gas limit required to complete the deposit on nil-chain..
     */
    function depositERC20(address _token, address _to, uint256 _amount, uint256 _gasLimit) external payable;

    /**
     * @notice Deposits ERC20 tokens to the nil-chain for a specified recipient and calls a function on the recipient's
     * contract.
     * @param _token The address of the ERC20 in L1 token to deposit.
     * @param _to The recipient address to receive the token in nil-chain.
     * @param _amount The amount of tokens to deposit.
     * @param _data Optional data to forward to the recipient's account.
     * @param _gasLimit The gas limit required to complete the deposit on nil-chain.
     */
    function depositERC20AndCall(
        address _token,
        address _to,
        uint256 _amount,
        bytes memory _data,
        uint256 _gasLimit
    )
        external
        payable;
}
