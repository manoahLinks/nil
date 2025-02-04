import { MockTransport } from "../transport/MockTransport.js";
import { CometaService } from "./CometaService.js";
import type { ContractData } from "./CometaTypes.js";

test("getContract", async ({ expect }) => {
  const fn = vi.fn();
  fn.mockReturnValue({});
  const cometa = new CometaService({
    transport: new MockTransport(fn),
    shardId: 1,
  });

  await cometa.getContract("0x12345");

  expect(fn).toHaveBeenCalledOnce();
  expect(fn).toHaveBeenLastCalledWith({
    method: "cometa_getContract",
    params: ["0x12345"],
  });
});

test("getLocation", async ({ expect }) => {
  const fn = vi.fn();
  fn.mockReturnValue({});
  const cometa = new CometaService({
    transport: new MockTransport(fn),
    shardId: 1,
  });

  await cometa.getLocation("0x12345", 1);

  expect(fn).toHaveBeenCalledOnce();
  expect(fn).toHaveBeenLastCalledWith({
    method: "cometa_getLocation",
    params: ["0x12345", 1],
  });
});

test("compileContract", async ({ expect }) => {
  const fn = vi.fn();
  fn.mockReturnValue({});
  const cometa = new CometaService({
    transport: new MockTransport(fn),
    shardId: 1,
  });

  await cometa.compileContract("inputJson");

  expect(fn).toHaveBeenCalledOnce();
  expect(fn).toHaveBeenLastCalledWith({
    method: "cometa_compileContract",
    params: ["inputJson"],
  });
});

test("registerContractData", async ({ expect }) => {
  const fn = vi.fn();
  fn.mockReturnValue({});
  const cometa = new CometaService({
    transport: new MockTransport(fn),
    shardId: 1,
  });

  await cometa.registerContractData({} as ContractData, "0x12345");

  expect(fn).toHaveBeenCalledOnce();
  expect(fn).toHaveBeenLastCalledWith({
    method: "cometa_registerContractData",
    params: [{}, "0x12345"],
  });
});

test("registerContract", async ({ expect }) => {
  const fn = vi.fn();
  fn.mockReturnValue({});
  const cometa = new CometaService({
    transport: new MockTransport(fn),
    shardId: 1,
  });

  await cometa.registerContract("input", "0x12345");

  expect(fn).toHaveBeenCalledOnce();
  expect(fn).toHaveBeenLastCalledWith({
    method: "cometa_registerContract",
    params: ["input", "0x12345"],
  });
});

test("getAbi", async ({ expect }) => {
  const fn = vi.fn();
  fn.mockReturnValue({});
  const cometa = new CometaService({
    transport: new MockTransport(fn),
    shardId: 1,
  });

  await cometa.getAbi("0x12345");

  expect(fn).toHaveBeenCalledOnce();
  expect(fn).toHaveBeenLastCalledWith({
    method: "cometa_getAbi",
    params: ["0x12345"],
  });
});

test("getSourceCode", async ({ expect }) => {
  const fn = vi.fn();
  fn.mockReturnValue({});
  const cometa = new CometaService({
    transport: new MockTransport(fn),
    shardId: 1,
  });

  await cometa.getSourceCode("0x12345");

  expect(fn).toHaveBeenCalledOnce();
  expect(fn).toHaveBeenLastCalledWith({
    method: "cometa_getSourceCode",
    params: ["0x12345"],
  });
});

test("decodeTransactionsCallData", async ({ expect }) => {
  const fn = vi.fn();
  fn.mockReturnValue({});
  const cometa = new CometaService({
    transport: new MockTransport(fn),
    shardId: 1,
  });

  await cometa.decodeTransactionsCallData([]);

  expect(fn).toHaveBeenCalledOnce();
  expect(fn).toHaveBeenLastCalledWith({
    method: "cometa_decodeTransactionsCallData",
    params: [[]],
  });
});
