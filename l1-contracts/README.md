<h1 align="center">l1-contracts</h1>

<br />

<p align="center">
  The =nil; L1 contract to be deployed on Ethereum.
</p>


## Table of contents

* [Overview](#overview)
* [Installation](#installation)
* [Usage](#usage)

## Overview

This project contains the =nil; L1 Solidity smart contract as well as the Hardhat tasks and Ignition modules for their deployment. 

The `NilChain.sol` contract fulfils the following functions:

* It is meant to be deployed on Ethereum
* It is used by [the sync committee when submitting proofs for verification](https://docs.nil.foundation/nil/core-concepts/transaction-lifecycle/#definition)
* It also handles state root updates

## Installation

Clone the repository:

```bash
git clone https://github.com/NilFoundation/nil.git
cd ./nil/l1-contracts
```
Install dependencies:

```bash
npm install
```

Then, create an `.env` file and set the following variables:

```
WALLET_ADDRESS:
PRIVATE_KEY:
```

Note that `WALLET_ADDRESS` will act as the owner of `NilChain` and it will also be used to run the sync committee.

`NilChain` can then be deployed using either [`Nil.js`](https://docs.nil.foundation/nil/niljs/deploying-smart-contract), the [=nil; CLI](https://docs.nil.foundation/nil/nilcli/getting-started) or Hardhat. 

## Usage

To compile the contract:

```bash
npx hardhat compile
```

To deploy the contract using Hardhat:

```bash
npx hardhat deploy --network local
```
