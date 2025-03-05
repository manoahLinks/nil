// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@nilfoundation/smart-contracts/contracts/Nil.sol";
import "@nilfoundation/smart-contracts/contracts/NilTokenBase.sol";

// The LendingPool contract facilitates lending and borrowing of tokens, and handles collateral management.
contract LendingPool is NilBase, NilTokenBase {
    address public globalLedger; // Address of the GlobalLedger contract that tracks deposits and loans
    address public interestManager; // Address of the InterestManager contract for interest rate calculations
    address public oracle; // Address of the Oracle contract to get token prices for collateral calculations
    TokenId public usdt; // TokenId for USDT (stablecoin)
    TokenId public eth; // TokenId for ETH (used as collateral)

    // Constructor to initialize the LendingPool contract with addresses for dependencies (GlobalLedger, InterestManager, Oracle, USDT, ETH)
    constructor(
        address _globalLedger,
        address _interestManager,
        address _oracle,
        TokenId _usdt,
        TokenId _eth
    ) {
        globalLedger = _globalLedger;
        interestManager = _interestManager;
        oracle = _oracle;
        usdt = _usdt;
        eth = _eth;
    }

    // Deposit function to deposit tokens into the lending pool
    function deposit() public payable {
        // Retrieve the tokens being sent in the transaction
        Nil.Token[] memory tokens = Nil.txnTokens();

        // Encoding the call to the GlobalLedger to record the deposit
        bytes memory callData = abi.encodeWithSignature(
            "recordDeposit(address,address,uint256)",
            msg.sender, // The user making the deposit
            tokens[0].id, // The token being deposited (usdt or eth)
            tokens[0].amount // The amount of the token being deposited
        );

        // Making an asynchronous call to the GlobalLedger to record the deposit
        Nil.asyncCall(globalLedger, address(this), 0, callData);
    }

    // Borrow function allows a user to borrow tokens (either USDT or ETH)
    function borrow(uint256 amount, TokenId borrowToken) public payable {
        // Ensure the token being borrowed is either USDT or ETH
        require(borrowToken == usdt || borrowToken == eth, "Invalid token");

        // Ensure that the LendingPool has enough liquidity of the requested borrow token
        require(
            Nil.tokenBalance(address(this), borrowToken) >= amount,
            "Insufficient funds"
        );

        // Determine which collateral token will be used (opposite of the borrow token)
        TokenId collateralToken = (borrowToken == usdt) ? eth : usdt;

        // Prepare a call to the Oracle to get the price of the borrow token
        bytes memory callData = abi.encodeWithSignature(
            "getPrice(address)",
            borrowToken
        );

        // Encoding the context to process the loan after the price is fetched
        bytes memory context = abi.encodeWithSelector(
            this.processLoan.selector,
            msg.sender, // Borrower's address
            amount, // Amount the borrower wants to borrow
            borrowToken, // Token being borrowed
            collateralToken // Token being used as collateral
        );

        // Send a request to the Oracle to get the price of the borrow token.
        // Here 9_000_000 is the fee that is retained from the feeCredit for processing the response transaction which is for the execution of processLoan()
        Nil.sendRequest(oracle, 0, 9_000_000, context, callData);
    }

    // Callback function to process the loan after the price data is retrieved from Oracle
    function processLoan(
        bool success,
        bytes memory returnData,
        bytes memory context
    ) public payable {
        // Ensure the Oracle call was successful
        require(success, "Oracle call failed");

        // Decode the context to extract borrower details, loan amount, and collateral token
        (
            address borrower,
            uint256 amount,
            TokenId borrowToken,
            TokenId collateralToken
        ) = abi.decode(context, (address, uint256, TokenId, TokenId));

        // Decode the price data returned from the Oracle
        uint256 borrowTokenPrice = abi.decode(returnData, (uint256));
        // Calculate the loan value in USD
        uint256 loanValueInUSD = amount * borrowTokenPrice;
        // Calculate the required collateral (120% of the loan value)
        uint256 requiredCollateral = (loanValueInUSD * 120) / 100;

        // Prepare a call to GlobalLedger to check the user's collateral balance
        bytes memory ledgerCallData = abi.encodeWithSignature(
            "getDeposit(address,address)",
            borrower,
            collateralToken
        );

        // Encoding the context to finalize the loan once the collateral is validated
        bytes memory ledgerContext = abi.encodeWithSelector(
            this.finalizeLoan.selector,
            borrower,
            amount,
            borrowToken,
            requiredCollateral
        );

        // Send request to GlobalLedger to get the user's collateral
        // Here 6_000_000 is the fee that is retained from the feeCredit for processing the response transaction which is for the execution of finalizeLoan()
        Nil.sendRequest(
            globalLedger,
            0,
            6_000_000,
            ledgerContext,
            ledgerCallData
        );
    }

    // Finalize the loan by ensuring sufficient collateral and recording the loan in GlobalLedger
    function finalizeLoan(
        bool success,
        bytes memory returnData,
        bytes memory context
    ) public payable {
        // Ensure the collateral check was successful
        require(success, "Ledger call failed");

        // Decode the context to extract loan details
        (
            address borrower,
            uint256 amount,
            TokenId borrowToken,
            uint256 requiredCollateral
        ) = abi.decode(context, (address, uint256, TokenId, uint256));

        // Decode the user's collateral balance from GlobalLedger
        uint256 userCollateral = abi.decode(returnData, (uint256));

        // Check if the user has enough collateral to cover the loan
        require(
            userCollateral >= requiredCollateral,
            "Insufficient collateral"
        );

        // Record the loan in GlobalLedger
        bytes memory recordLoanCallData = abi.encodeWithSignature(
            "recordLoan(address,address,uint256)",
            borrower,
            borrowToken,
            amount
        );
        Nil.asyncCall(globalLedger, address(this), 0, recordLoanCallData);

        // Send the borrowed tokens to the borrower
        sendTokenInternal(borrower, borrowToken, amount);
    }

    // Repay loan function called by the borrower to repay their loan
    function repayLoan() public payable {
        // Retrieve the tokens being sent in the transaction
        Nil.Token[] memory tokens = Nil.txnTokens();

        // Prepare to query the loan details from GlobalLedger
        bytes memory callData = abi.encodeWithSignature(
            "getLoanDetails(address)",
            msg.sender // The borrower’s address
        );

        // Encoding the context to handle repayment after loan details are fetched
        bytes memory context = abi.encodeWithSelector(
            this.handleRepayment.selector,
            msg.sender, // Borrower's address
            tokens[0].amount // Repayment amount
        );

        // Send request to GlobalLedger to fetch loan details
        // Here 11_000_000 is the fee that is retained from the feeCredit for processing the response transaction which is for the execution of handleRepayment()
        Nil.sendRequest(globalLedger, 0, 11_000_000, context, callData);
    }

    // Handle the loan repayment, calculate the interest, and update GlobalLedger
    function handleRepayment(
        bool success,
        bytes memory returnData,
        bytes memory context
    ) public payable {
        // Ensure the GlobalLedger call was successful
        require(success, "Ledger call failed");

        // Decode context and loan details
        (address borrower, uint256 sentAmount) = abi.decode(
            context,
            (address, uint256)
        );
        (uint256 amount, TokenId token) = abi.decode(
            returnData,
            (uint256, TokenId)
        );

        // Ensure the borrower has an active loan
        require(amount > 0, "No active loan");

        // Request the interest rate from the InterestManager
        bytes memory interestCallData = abi.encodeWithSignature(
            "getInterestRate()"
        );
        bytes memory interestContext = abi.encodeWithSelector(
            this.processRepayment.selector,
            borrower,
            amount,
            token,
            sentAmount
        );

        // Send request to InterestManager to fetch interest rate
        // Here 8_000_000 is the fee that is retained from the feeCredit for processing the response transaction which is for the execution of processRepayment()
        Nil.sendRequest(
            interestManager,
            0,
            8_000_000,
            interestContext,
            interestCallData
        );
    }

    // Process the repayment, calculate the total repayment including interest
    function processRepayment(
        bool success,
        bytes memory returnData,
        bytes memory context
    ) public payable {
        // Ensure the interest rate call was successful
        require(success, "Interest rate call failed");

        // Decode the repayment details and the interest rate
        (
            address borrower,
            uint256 amount,
            TokenId token,
            uint256 sentAmount
        ) = abi.decode(context, (address, uint256, TokenId, uint256));

        // Decode the interest rate from the response
        uint256 interestRate = abi.decode(returnData, (uint256));
        // Calculate the total repayment amount (principal + interest)
        uint256 totalRepayment = amount + ((amount * interestRate) / 100);

        // Ensure the borrower has sent sufficient funds for the repayment
        require(sentAmount >= totalRepayment, "Insufficient funds");

        // Clear the loan and release collateral
        bytes memory clearLoanCallData = abi.encodeWithSignature(
            "recordLoan(address,address,uint256)",
            borrower,
            token,
            0 // Mark the loan as repaid
        );
        bytes memory releaseCollateralContext = abi.encodeWithSelector(
            this.releaseCollateral.selector,
            borrower,
            token
        );

        // Send request to GlobalLedger to update the loan status
        Nil.sendRequest(
            globalLedger,
            0,
            6_000_000,
            releaseCollateralContext,
            clearLoanCallData
        );
    }

    // Release the collateral after the loan is repaid
    function releaseCollateral(
        bool success,
        bytes memory returnData,
        bytes memory context
    ) public payable {
        // Ensure the loan clearing was successful
        require(success, "Loan clearing failed");

        // Silence unused variable warning
        returnData;

        // Decode context for borrower and collateral token
        (address borrower, TokenId borrowToken) = abi.decode(
            context,
            (address, TokenId)
        );

        // Determine the collateral token (opposite of borrow token)
        TokenId collateralToken = (borrowToken == usdt) ? eth : usdt;

        // Request collateral amount from GlobalLedger
        bytes memory getCollateralCallData = abi.encodeWithSignature(
            "getDeposit(address,address)",
            borrower,
            collateralToken
        );

        // Context to send collateral to the borrower
        bytes memory sendCollateralContext = abi.encodeWithSelector(
            this.sendCollateral.selector,
            borrower,
            collateralToken
        );

        // Send request to GlobalLedger to retrieve the collateral
        // Here 3_50_000 is the fee that is retained from the feeCredit for processing the response transaction which is for the execution of sendCollateral()
        Nil.sendRequest(
            globalLedger,
            0,
            3_50_000,
            sendCollateralContext,
            getCollateralCallData
        );
    }

    // Send the collateral back to the borrower
    function sendCollateral(
        bool success,
        bytes memory returnData,
        bytes memory context
    ) public payable {
        // Ensure the collateral retrieval was successful
        require(success, "Failed to retrieve collateral");

        // Decode the collateral details
        (address borrower, TokenId collateralToken) = abi.decode(
            context,
            (address, TokenId)
        );
        uint256 collateralAmount = abi.decode(returnData, (uint256));

        // Ensure there's collateral to release
        require(collateralAmount > 0, "No collateral to release");

        // Ensure sufficient balance in the LendingPool to send collateral
        require(
            Nil.tokenBalance(address(this), collateralToken) >=
                collateralAmount,
            "Insufficient funds"
        );

        // Send the collateral tokens to the borrower
        sendTokenInternal(borrower, collateralToken, collateralAmount);
    }
}
