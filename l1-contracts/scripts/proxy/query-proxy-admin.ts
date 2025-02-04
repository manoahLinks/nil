import { ethers, upgrades } from "hardhat";

// npx hardhat run scripts/proxy/query-proxy-admin.ts --network sepolia
async function main() {
  // Retrieve and log the ProxyAdmin address
  const proxyAddress = '0x8711eEEd79B070C9f9dF7d599CD1b0aA637bb40b';
  const proxyAdminAddress = await upgrades.erc1967.getAdminAddress(proxyAddress);
  // 0x2423458DB2E15e4C7067344a95eEd365729F0047
  console.log(`ProxyAdmin for proxy: ${proxyAddress} is: ${proxyAdminAddress}`);

  // Retrieve and log the implementation address
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
  // 0x72AB01Df6c96733370B469e4b521cE6fa24b833d
  console.log(`Implementation address for proxy: ${proxyAddress} is: ${implementationAddress}`);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });