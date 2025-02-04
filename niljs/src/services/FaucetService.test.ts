import { defaultAddress } from "../../test/mocks/address.js";
import { MockTransport } from "../transport/MockTransport.js";
import { addHexPrefix } from "../utils/hex.js";
import { FaucetService } from "./FaucetService.js";

test("getAllFaucets", async ({ expect }) => {
  const fn = vi.fn();
  fn.mockReturnValue({});
  const service = new FaucetService({
    transport: new MockTransport(fn),
    shardId: 1,
  });

  await service.getAllFaucets();

  expect(fn).toHaveBeenCalledOnce();
  expect(fn).toHaveBeenLastCalledWith({
    method: "faucet_getFaucets",
    params: [],
  });
});

test("topUp", async ({ expect }) => {
  const fn = vi.fn();
  fn.mockReturnValue({});
  const service = new FaucetService({
    transport: new MockTransport(fn),
    shardId: 1,
  });

  await service.topUp({
    smartAccountAddress: addHexPrefix(defaultAddress),
    faucetAddress: addHexPrefix(defaultAddress),
    amount: 100,
  });

  expect(fn).toHaveBeenCalledOnce();
  expect(fn).toHaveBeenLastCalledWith({
    method: "faucet_topUpViaFaucet",
    params: [addHexPrefix(defaultAddress), addHexPrefix(defaultAddress), 100],
  });
});
