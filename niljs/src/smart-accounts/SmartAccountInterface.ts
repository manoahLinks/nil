import type { Hex } from "../types/Hex.js";
import type { SendTransactionParams } from "./SmartAccountV1/types.js";

export interface SmartAccountInterface {
  sendTransaction({
    to,
    refundTo,
    bounceTo,
    data,
    abi,
    functionName,
    args,
    deploy,
    seqno,
    feeCredit,
    value,
    tokens,
    chainId,
  }: SendTransactionParams): Promise<Hex>;
}
