import type { Abi, Address } from "abitype";
import type { XOR } from "ts-essentials";
import type { PublicClient } from "../../clients/PublicClient.js";
import type { ISigner } from "../../signers/types/ISigner.js";
import type { Hex } from "../../types/Hex.js";
import type { Token } from "../../types/Token.js";

type WaletV1BaseConfig = {
  pubkey: Uint8Array | Hex;
  client: PublicClient;
  signer: ISigner;
};

type SmartAccountV1ConfigCalculated = WaletV1BaseConfig & {
  salt: Uint8Array | bigint;
  shardId: number;
  address?: undefined;
};

type SmartAccountV1ConfigAddress = WaletV1BaseConfig & {
  address: Address | Uint8Array;
  salt?: undefined;
  shardId?: undefined;
};

/**
 * Represents the smart account configuration.
 *
 * @typedef {SmartAccountV1Config}
 */
export type SmartAccountV1Config = SmartAccountV1ConfigCalculated | SmartAccountV1ConfigAddress;
/**
 * Represents the transaction call params.
 *

 * @typedef {CallParams}
 */
export type CallParams = {
  to: Address;
  data: Uint8Array;
  value: bigint;
};

export type SendBaseTransactionParams = {
  to: Address | Uint8Array;
  refundTo?: Address | Uint8Array;
  bounceTo?: Address | Uint8Array;
  data?: Uint8Array | Hex;
  value?: bigint;
  feeCredit?: bigint;
  maxPriorityFeePerGas?: bigint;
  maxFeePerGas?: bigint;
  tokens?: Token[];
  deploy?: boolean;
  seqno?: number;
  chainId?: number;
};

export type SendDataTransactionParams = SendBaseTransactionParams & {
  data?: Uint8Array | Hex;
};

export type SendAbiTransactionParams = SendBaseTransactionParams & {
  abi: Abi;
  functionName: string;
  args?: unknown[];
};

/**
 * Represents the params for sending a transaction.
 *
 * @typedef {SendTransactionParams}
 */
export type SendTransactionParams = XOR<SendDataTransactionParams, SendAbiTransactionParams>;

export type SendSyncBaseTransactionParams = {
  to: Address | Uint8Array;
  value: bigint;
  gas: bigint;
  maxPriorityFeePerGas: bigint;
  maxFeePerGas: bigint;
  seqno?: number;
};

export type SendSyncDataTransactionParams = SendSyncBaseTransactionParams & {
  data?: Uint8Array | Hex;
};

export type SendSyncAbiTransactionParams = SendSyncBaseTransactionParams & {
  abi: Abi;
  functionName: string;
  args?: unknown[];
};

/**
 * Represents the params for sending a transaction synchronously.
 *
 * @typedef {SendSyncTransactionParams}
 */
export type SendSyncTransactionParams = XOR<
  SendSyncDataTransactionParams,
  SendSyncAbiTransactionParams
>;

/**
 * Represents the params for making a request to the smart account.
 *
 * @typedef {RequestParams}
 */
export type RequestParams = {
  data: Uint8Array;
  deploy: boolean;
  seqno?: number;
  chainId?: number;
  feeCredit?: bigint;
  maxPriorityFeePerGas?: bigint;
  maxFeePerGas?: bigint;
};

/**
 * Represents the params for deploying a smart contract.
 *
 * @typedef {DeployParams}
 */
export type DeployParams = {
  bytecode: Uint8Array | Hex;
  abi?: Abi;
  args?: unknown[];
  salt: Uint8Array | bigint;
  shardId: number;
  feeCredit?: bigint;
  maxPriorityFeePerGas?: bigint;
  maxFeePerGas?: bigint;
  value?: bigint;
  seqno?: number;
  chainId?: number;
};
