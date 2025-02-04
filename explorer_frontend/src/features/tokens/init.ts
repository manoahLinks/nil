import { HttpTransport } from "@nilfoundation/niljs";
import { sample } from "effector";
import { $endpoint } from "../account-connector/model";
import { $faucets, fetchFaucetsEvent, fetchFaucetsFx } from "./model";

fetchFaucetsFx.use(async (endpoint) => {
  const faucetService = new FaucetService({
    transport: new HttpTransport({ endpoint }),
  });

  return await faucetService.getAllFaucets();
});

sample({
  clock: fetchFaucetsEvent,
  source: $endpoint,
  target: fetchFaucetsFx,
});

$endpoint.watch((endpoint) => {
  if (endpoint) {
    fetchFaucetsEvent();
  }
});

$faucets.on(fetchFaucetsFx.doneData, (_, balance) => balance);

fetchFaucetsEvent();
