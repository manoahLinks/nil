// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IL1Bridge {
  error UnAuthorizedCaller();
  error InvalidDepositType();

  /*//////////////////////////////////////////////////////////////////////////
                             PUBLIC MUTATION FUNCTIONS   
    //////////////////////////////////////////////////////////////////////////*/

  function cancelDeposit(bytes32 messageHash) external payable;
}
