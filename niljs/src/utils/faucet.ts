import { PublicClient } from "../clients/PublicClient.js";
import { FaucetService } from "../services/FaucetService.js";
import { HttpTransport } from "../transport/HttpTransport.js";
import type { Hex } from "../types/Hex.js";
import { getShardIdFromAddress } from "./address.js";

export async function topUp({
  address,
  faucetEndpoint,
  rpcEndpoint,
  token = "NIL",
  amount = 1e18,
}: {
  address: Hex;
  faucetEndpoint: string;
  rpcEndpoint: string;
  token?: string;
  amount?: number;
}): Promise<void> {
  const shardId = getShardIdFromAddress(address);

  const client = new PublicClient({
    transport: new HttpTransport({
      endpoint: rpcEndpoint,
    }),
    shardId: shardId,
  });

  const faucetService = new FaucetService({
    transport: new HttpTransport({
      endpoint: faucetEndpoint,
    }),
  });

  const faucets = await faucetService.getAllFaucets();
  const faucet = faucets[token];

  await faucetService.topUpAndWaitUntilCompletion(
    {
      faucetAddress: faucet,
      smartAccountAddress: address,
      amount: amount,
    },
    client,
  );
}
