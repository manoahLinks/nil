import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deployNilChain: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, ethers } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  const chainId = 1337;
  const version = 1;

  const nilChain = await deploy("NilChain", {
    from: deployer,
    args: [chainId, version],
    log: true,
  });

  console.log("NilChain deployed to:", nilChain.address);
};

export default deployNilChain;
deployNilChain.tags = ["NilChain"];