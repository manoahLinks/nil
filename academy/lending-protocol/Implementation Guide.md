### Complete Implementation Guide: Lending Protocol on =nil; Foundation

This guide provides a **step-by-step walkthrough** for the example implementation of the decentralized lending and borrowing protocol on **=nil;**, focusing on **sharded smart contract architecture** and the lifecycle of core actions like **opening a loan**, **borrowing funds**, and **repaying the loan**. We'll go through each contract, their functions, how they interact, and the details of important function calls, including the **`sendRequestWithTokens`, `asyncCall`** methods and how they are used throughout the system.

### 1. **Deployment and Contract Overview**

Before diving into the workflows for opening a loan, borrowing funds, and repaying a loan, it’s important to understand the smart contracts and their deployment.

#### **Core Contracts**

1. **GlobalLedger**: This contract tracks user deposits and loans, serving as the centralized state manager for the protocol. It stores the user’s deposit balance and the loan balance.
2. **InterestManager**: This contract manages interest rates, which are used when calculating the repayment amounts for loans.
3. **LendingPool**: This is the core contract for interacting with the lending protocol. It handles user deposits, loans, and repayments.
4. **Oracle**: Provides the token price data needed for collateral calculations when a loan is opened.

The deployment process occurs using Hardhat, where the smart contracts are deployed on different shards:

- **InterestManager** (Shard 2)
- **GlobalLedger** (Shard 3)
- **Oracle** (Shard 4)
- **LendingPool** (Shard 1)

---

### 2. **Core Workflow and Interactions:**

Now that we have an understanding of the contracts, let’s dive deeper into how each interaction happens when a user deposits tokens, borrows funds, and repays the loan.

---

#### **A. Deposit Process**:

When a user deposits tokens into the **LendingPool**, the following steps occur:

1.  **Deposit Transaction**:

    - The user sends a transaction to the `deposit()` function in the **LendingPool** contract.
    - The **LendingPool** contract extracts the token ID and the deposit amount using `Nil.txnTokens()`. This helps determine which token the user is depositing (either USDT or ETH).
    - One important thing to notice here is that in the `LendingPool` contract, the `deposit()` function calls `recordDeposit()` in the `GlobalLedger` contract using the signature `recordDeposit(address,address,uint256)`. Although the `GlobalLedger` function expects a `TokenId` (which is an alias for `address`), Solidity requires using built-in types in the ABI encoding. Therefore, when we encode the function call using `abi.encodeWithSignature`, we pass it as `address` (tokens[0].id), as `TokenId` is treated as an `address` type. This is followed everywhere there is an async communication to another contract and the function to be inviked has a argument of type `TokenId` .

    ```solidity
    function deposit() public payable {
        Nil.Token[] memory tokens = Nil.txnTokens();
        bytes memory callData = abi.encodeWithSignature(
            "recordDeposit(address,address,uint256)",
            msg.sender,
            tokens[0].id,
            tokens[0].amount
        );
        Nil.asyncCall(globalLedger, address(this), 0, callData);
    }
    ```

2.  **Asynchronous Call to GlobalLedger**:

    - The `deposit()` function calls `Nil.asyncCall` to invoke `recordDeposit()` in the **GlobalLedger** contract. This is an asynchronous call, meaning the **LendingPool** contract doesn't wait for **GlobalLedger** to finish executing before moving on.

    - `recordDeposit()` updates the user’s deposit in the **GlobalLedger** contract.
      ```solidity
      function recordDeposit(address user, TokenId token, uint256 amount) public {
          deposits[user][token] += amount;
      }
      ```

3.  **GlobalLedger Updates Deposit**:
    - **GlobalLedger** updates the user's balance by adding the deposited amount to the `deposits[user][token]` mapping, ensuring that the user’s balance is properly tracked.

---

#### **B. Loan Opening Process**:

The core functionality of the lending protocol is opening a loan. When a user wishes to borrow tokens, the process follows these steps:

1. **Borrow Transaction**:

   - The user calls the `borrow()` function in the **LendingPool** contract.
   - The **LendingPool** contract first checks if there is sufficient liquidity for the requested token (e.g., USDT or ETH) by verifying the balance in the **LendingPool** contract.

   ```solidity
   function borrow(uint256 amount, TokenId borrowToken) public payable {
       require(borrowToken == usdt || borrowToken == eth, "Invalid token");
       require(Nil.tokenBalance(address(this), borrowToken) >= amount, "Insufficient funds");
       TokenId collateralToken = (borrowToken == usdt) ? eth : usdt;
   }
   ```

2. **Price Retrieval from Oracle**:

   - The **LendingPool** contract sends an asynchronous request to the **Oracle** contract to get the price of the requested borrow token (either USDT or ETH). The `getPrice()` function is called using `sendRequest` and the function selector passed inside `abi.encodeWithSelector` is triggered on callback from the `Oracle`.

   ```solidity
   bytes memory callData = abi.encodeWithSignature("getPrice(address)", borrowToken);
   bytes memory context = abi.encodeWithSelector(
       this.processLoan.selector, msg.sender, amount, borrowToken, collateralToken
   );
   Nil.sendRequest(oracle, 0, 9_000_000, context, callData);
   ```

3. **Asynchronous Request**:

   - The `sendRequest()` function sends a request to the **Oracle** contract, which will asynchronously return the price of the borrow token.
   - `context` is passed along with the request to ensure that when the Oracle responds, the `LendingPool` knows which function to trigger along with passed data.

4. **Processing Loan**:

   - When the Oracle responds with the price, **LendingPool** triggers the `processLoan()` function.
   - In `processLoan()`, the loan value in USD is calculated using the price returned by the Oracle, and the required collateral is calculated. The collateral is set at 120% of the loan amount.

   ```solidity
   function processLoan(bool success, bytes memory returnData, bytes memory context) public payable {
       require(success, "Oracle call failed");
       (address borrower, uint256 amount, TokenId borrowToken, TokenId collateralToken) =
           abi.decode(context, (address, uint256, TokenId, TokenId));

       uint256 borrowTokenPrice = abi.decode(returnData, (uint256));
       uint256 loanValueInUSD = amount * borrowTokenPrice;
       uint256 requiredCollateral = (loanValueInUSD * 120) / 100;
   }
   ```

5. **Check Collateral in GlobalLedger**:

   - After calculating the required collateral, **LendingPool** calls **GlobalLedger** to check if the borrower has sufficient collateral.
   - If the borrower’s collateral is sufficient, **LendingPool** proceeds to finalize the loan.

   ```solidity
   bytes memory ledgerCallData = abi.encodeWithSignature(
       "getDeposit(address,address)", borrower, collateralToken
   );
   bytes memory ledgerContext = abi.encodeWithSelector(
       this.finalizeLoan.selector, borrower, amount, borrowToken, requiredCollateral
   );
   Nil.sendRequest(globalLedger, 0, 6_000_000, ledgerContext, ledgerCallData);
   ```

6. **Finalize Loan**:

   - If the collateral is sufficient, **LendingPool** calls `finalizeLoan()`, which records the loan details in **GlobalLedger** and sends the borrowed token to the borrower.

   ```solidity
   function finalizeLoan(bool success, bytes memory returnData, bytes memory context) public payable {
       require(success, "Ledger call failed");
       (address borrower, uint256 amount, TokenId borrowToken, uint256 requiredCollateral) =
           abi.decode(context, (address, uint256, TokenId, uint256));

       (uint256 userCollateral) = abi.decode(returnData, (uint256));
       require(userCollateral >= requiredCollateral, "Insufficient collateral");

       bytes memory recordLoanCallData = abi.encodeWithSignature(
           "recordLoan(address,address,uint256)", borrower, borrowToken, amount
       );
       Nil.asyncCall(globalLedger, address(this), 0, recordLoanCallData);
       sendTokenInternal(borrower, borrowToken, amount);
   }
   ```

---

#### **C. Loan Repayment Process**:

The loan repayment process is triggered when the borrower wants to pay back the loan.

1. **Repayment Transaction**:

   - The borrower sends a transaction to **LendingPool** invoking the `repayLoan()` function.
   - The **LendingPool** contract first checks if the borrower has an active loan by querying **GlobalLedger** using `getLoanDetails()`.

   ```solidity
   function repayLoan() public payable {
       Nil.Token[] memory tokens = Nil.txnTokens();
       bytes memory callData = abi.encodeWithSignature("getLoanDetails(address)", msg.sender);
       bytes memory context = abi.encodeWithSelector(this.handleRepayment.selector, msg.sender, tokens[0].amount);
       Nil.sendRequest(globalLedger, 0, 11_000_000, context, callData);
   }
   ```

2. **Handling Repayment**:

   - Once the loan details are fetched, **LendingPool** calls `handleRepayment()` to process the repayment.
   - It calculates the total repayment amount (principal + interest). The interest rate is fetched asynchronously from the **InterestManager** contract.

   ```solidity
   function handleRepayment(bool success, bytes memory returnData, bytes memory context) public payable {
       require(success, "Ledger call failed");
       (address borrower, uint256 sentAmount) = abi.decode(context, (address, uint256));
       (uint256 amount, TokenId token) = abi.decode(returnData, (uint256, TokenId));
       require(amount > 0, "No active loan");

       bytes memory interestCallData = abi.encodeWithSignature("getInterestRate()");
       bytes memory interestContext = abi.encodeWithSelector(
           this.processRepayment.selector, borrower, amount, token, sentAmount
       );
       Nil.sendRequest(interestManager, 0, 8_000_000, interestContext, interestCallData);
   }
   ```

3. **Repayment Finalization**:

   - The interest rate is returned from **InterestManager**, and **LendingPool** calculates the total repayment required.
   - If the borrower has sent the correct amount, **LendingPool** clears the loan by calling **GlobalLedger** to mark the loan as paid and release the collateral.

   ```solidity
   function processRepayment(bool success, bytes memory returnData, bytes memory context) public payable {
       require(success, "Interest rate call failed");

       (address borrower, uint256 amount, TokenId token, uint256 sentAmount) = abi.decode(context, (address, uint256, TokenId, uint256));
       uint256 interestRate = abi.decode(returnData, (uint256));
       uint256 totalRepayment = amount + ((amount * interestRate) / 100);

       require(sentAmount >= totalRepayment, "Insufficient funds");

       bytes memory clearLoanCallData = abi.encodeWithSignature("recordLoan(address,address,uint256)", borrower, token, 0);
       bytes memory releaseCollateralContext = abi.encodeWithSelector(this.releaseCollateral.selector, borrower, token);
       Nil.sendRequest(globalLedger, 0, 6_000_000, releaseCollateralContext, clearLoanCallData);
   }
   ```

4. **Release Collateral**:

   - Once the loan is repaid, **LendingPool** triggers the release of the collateral by calling `releaseCollateral()` and sending the collateral tokens back to the borrower.

   ```solidity
   function releaseCollateral(bool success, bytes memory returnData, bytes memory context) public payable {
       require(success, "Loan clearing failed");
       (address borrower, TokenId borrowToken) = abi.decode(context, (address, TokenId));

       // Determine collateral token (usdt <-> ETH)
       TokenId collateralToken = (borrowToken == usdt) ? eth : usdt;
       bytes memory getCollateralCallData = abi.encodeWithSignature("getDeposit(address,address)", borrower, collateralToken);
       bytes memory sendCollateralContext = abi.encodeWithSelector(this.sendCollateral.selector, borrower, collateralToken);
       Nil.sendRequest(globalLedger, 0, 3_50_000, sendCollateralContext, getCollateralCallData);
   }
   ```

5. **Send Collateral**:

   - The borrower’s collateral is returned once the loan is successfully repaid, completing the transaction.

   ```solidity
   function sendCollateral(bool success, bytes memory returnData, bytes memory context) public payable {
       require(success, "Failed to retrieve collateral");

       (address borrower, TokenId collateralToken) = abi.decode(context, (address, TokenId));
       uint256 collateralAmount = abi.decode(returnData, (uint256));
       require(collateralAmount > 0, "No collateral to release");
       require(Nil.tokenBalance(address(this), collateralToken) >= collateralAmount, "Insufficient funds");

       sendTokenInternal(borrower, collateralToken, collateralAmount);
   }
   ```

### Conclusion

This guide covers the **complete implementation** of the example for a decentralized lending and borrowing protocol, detailing the interactions between contracts.
