import { generateRandomPrivateKey } from "@nilfoundation/niljs";
import { createClient, createFaucetClient, createSigner } from "../../src/features/blockchain";
import { generateRandomShard } from "../../src/features/utils";
import { testEnv } from "../testEnv.js";

// Helper function to set up test environment
export async function setup() {
  const privateKey = generateRandomPrivateKey();
  const shardId = generateRandomShard();
  const client = createClient(testEnv.endpoint, shardId);
  const signer = createSigner(privateKey);
  const faucetClient = createFaucetClient(testEnv.endpoint);

  return { client, signer, shardId, faucetClient };
}
