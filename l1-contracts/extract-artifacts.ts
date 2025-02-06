import fs from 'fs';
import path from 'path';

async function main() {
  const artifactsPath = path.join(__dirname, '../artifacts/contracts/NilChain.sol/NilChain.json');
  const artifacts = JSON.parse(fs.readFileSync(artifactsPath, 'utf8'));

  const abi = JSON.stringify(artifacts.abi, null, 2);
  const bytecode = artifacts.bytecode;

  fs.writeFileSync(path.join(__dirname, '../NilChain.abi'), abi);
  fs.writeFileSync(path.join(__dirname, '../NilChain.bin'), bytecode);

  console.log('ABI and bytecode files have been generated.');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});