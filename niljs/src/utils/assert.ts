import invariant from "tiny-invariant";
import { InvalidShardIdError } from "../errors/shardId.js";
import type { IPrivateKey } from "../signers/types/IPrivateKey.js";
import type { Hex } from "../types/Hex.js";
import { isAddress } from "./address.js";
import { isHexString } from "./hex.js";

const masterShardId = 0;

/**
 * Checks if the value is a string.
 * @throws Will throw an error if the value is not a hex string.
 * @param value - The value to check.
 * @param message - The message to throw if the value is not a hex string.
 */
const assertIsHexString = (value: Hex, message?: string): void => {
  invariant(isHexString(value), message ?? `Expected a hex string but got ${value}`);
};

/**
 * Checks if the value is a buffer.
 * @throws Will throw an error if value is not a buffer.
 * @param value - The value to check.
 * @param message - The message to throw if the value is not a buffer.
 */
const assertIsBuffer = (value: Uint8Array, message?: string): void => {
  invariant(value instanceof Uint8Array, message ?? `Expected a buffer but got ${value}`);
};

/**
 * Checks if provided private key is valid. If the value is a hex string with length 32 nothing is returned.
 * @throws Will throw an error if provided private key is invalid.
 * @param privateKey - The private key to check.
 * @param message - The message to throw if the private key is invalid.
 */
const assertIsValidPrivateKey = (privateKey: IPrivateKey, message?: string): void => {
  invariant(
    isHexString(privateKey) && privateKey.length === 32 * 2 + 2,
    message ?? `Expected a valid private key, but got ${privateKey}`,
  );
};

/**
 * Checks if the address is valid. If the address is valid, it returns nothing.
 * @param address - The address to check.
 * @param message - The message to throw if the address is invalid.
 */
const assertIsAddress = (address: string, message?: string): void => {
  invariant(isAddress(address), message ?? `Expected a valid address but got ${address}`);
};

/**
 * Checks if the shard id is valid. If the shard id is valid, it returns nothing.
 * @param shardId - The shard id to check.
 */
const assertIsValidShardId = (shardId?: number): void => {
  const isValid =
    typeof shardId === "number" &&
    Number.isInteger(shardId) &&
    shardId >= 0 &&
    shardId < 2 ** 16 &&
    shardId !== masterShardId;

  if (!isValid) {
    throw new InvalidShardIdError({ shardId });
  }
};

export {
  assertIsBuffer,
  assertIsHexString,
  assertIsValidPrivateKey,
  assertIsAddress,
  assertIsValidShardId,
};
