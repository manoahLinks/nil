import { waitTillCompleted } from "../../src/index.js";
import { generateRandomAddress, newClient, newFaucetService } from "./helpers.js";

const client = newClient();

test("Receipt test", async ({ expect }) => {
  const faucetService = newFaucetService();
  const faucets = await faucetService.getAllFaucets();

  const smartAccountAddress = generateRandomAddress();

  const faucetHash = await faucetService.topUp({
    faucetAddress: faucets.NIL,
    smartAccountAddress: smartAccountAddress,
    amount: 100,
  });

  const receipts = await waitTillCompleted(client, faucetHash);

  expect(receipts).toBeDefined();
  for (const receipt of receipts) {
    expect(receipt).toBeDefined();
    expect(receipt.gasPrice).toBeDefined();
    expect(receipt.gasUsed).toBeDefined();
    expect(receipt.gasPrice).toBeTypeOf("bigint");
  }
});
