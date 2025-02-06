import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";

task("query-owner", "Queries the owner of the NilChain contract")
  .addParam("contract", "The address of the NilChain contract")
  .setAction(async (taskArgs, hre: HardhatRuntimeEnvironment) => {
    const { ethers } = hre;

    const contractAddress = taskArgs.contract;

    // ABI of the NilChain contract (assuming it has an owner() function)
    const abi = [
      "function owner() view returns (address)"
    ];

    // Create a contract instance
    const nilChain = new ethers.Contract(contractAddress, abi, ethers.provider);

    // Query the owner
    const owner = await nilChain.owner();

    console.log("Owner of NilChain contract:", owner);
  });

export default {};