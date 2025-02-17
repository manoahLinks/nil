import { HttpTransport, PublicClient } from "@nilfoundation/niljs";
import { createDomain } from "effector";

export const healthcheckDomain = createDomain("healthcheck");

export const $rpcIsHealthy = healthcheckDomain.createStore<boolean>(true);
export const checkRpcHealthFx = healthcheckDomain.createEffect<string, boolean>();

export const pageVisibilityChanged = healthcheckDomain.createEvent<boolean>();
export const $isPageVisible = healthcheckDomain.createStore(document.visibilityState === "visible");

checkRpcHealthFx.use(async (endpoint: string) => {
  if (!endpoint) return true;

  try {
    const client = new PublicClient({
      transport: new HttpTransport({ endpoint }),
    });

    const response = await client.chainId();
    return typeof response === "number";
  } catch {
    return false;
  }
});
