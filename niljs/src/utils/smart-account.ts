import { PublicClient } from "../clients/PublicClient.js";
import { LocalECDSAKeySigner } from "../signers/LocalECDSAKeySigner.js";
import { generateRandomPrivateKey } from "../signers/privateKey.js";
import { SmartAccountV1 } from "../smart-accounts/SmartAccountV1/SmartAccountV1.js";
import { HttpTransport } from "../transport/HttpTransport.js";
import { topUp } from "./faucet.js";

export async function generateSmartAccount(options: {
  shardId: number;
  rpcEndpoint: string;
  faucetEndpoint: string;
}) {
  const client = new PublicClient({
    transport: new HttpTransport({
      endpoint: options.rpcEndpoint,
    }),
    shardId: options.shardId,
  });

  const signer = new LocalECDSAKeySigner({
    privateKey: generateRandomPrivateKey(),
  });

  const smartAccount = new SmartAccountV1({
    pubkey: signer.getPublicKey(),
    client: client,
    signer: signer,
    shardId: options.shardId,
    salt: BigInt(Math.floor(Math.random() * 10000)),
  });

  await topUp({
    address: smartAccount.address,
    rpcEndpoint: options.rpcEndpoint,
    faucetEndpoint: options.faucetEndpoint,
  });

  await smartAccount.selfDeploy();

  return smartAccount;
}
