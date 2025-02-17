import { convertEthToWei } from "@nilfoundation/niljs";
import {
  fetchBalance,
  fetchSmartAccountCurrencies,
  initializeOrDeploySmartAccount,
  sendCurrency,
  topUpAllCurrencies,
} from "../../src/features/blockchain";
import { Currency } from "../../src/features/components/currency";
import { getTokenAddressBySymbol } from "../../src/features/utils";
import { setup } from "./helper.ts";

test("Initialize and deploy smart account, fetch balance and tokens", async () => {
  // Set up test environment
  const { client, signer, shardId, faucetClient } = await setup();

  // 1. Deploy new smart account (no existing address)
  const smartAccount = await initializeOrDeploySmartAccount({
    client,
    signer,
    shardId,
    faucetClient,
  });

  // 2. TopUp with currencies
  await topUpAllCurrencies(smartAccount, faucetClient);

  expect(smartAccount).not.toBeNull();
  expect(smartAccount.address).toBeDefined();

  // 3. Fetch balance and tokens
  const balance = await fetchBalance(smartAccount);
  const tokens = await fetchSmartAccountCurrencies(smartAccount);

  expect(balance).not.toBeNull();
  expect(typeof balance).toBe("bigint");

  expect(tokens).not.toBeNull();
  expect(typeof tokens).toBe("object");

  // 4. Reinitialize with existing address
  const smartAccountReinit = await initializeOrDeploySmartAccount({
    client,
    signer,
    shardId,
    faucetClient,
    existingSmartAccountAddress: smartAccount.address,
  });

  expect(smartAccountReinit.address).toBe(smartAccount.address);

  // 5. Fetch balance and tokens again
  const balanceReinit = await fetchBalance(smartAccountReinit);
  const tokensReinit = await fetchSmartAccountCurrencies(smartAccountReinit);

  expect(balanceReinit).toBe(balance);
  expect(tokensReinit).toEqual(tokens);
});

test("Send NIL currency and token between accounts and validate balances", async () => {
  // 1. Set up sender account
  const senderSetup = await setup();
  const sender = await initializeOrDeploySmartAccount({
    client: senderSetup.client,
    signer: senderSetup.signer,
    shardId: senderSetup.shardId,
    faucetClient: senderSetup.faucetClient,
  });

  // 2. Set up recipient account (Always new)
  const recipientSetup = await setup();
  const recipient = await initializeOrDeploySmartAccount({
    client: recipientSetup.client,
    signer: recipientSetup.signer,
    shardId: recipientSetup.shardId,
    faucetClient: recipientSetup.faucetClient,
  });

  // 3. Top up sender with all currencies
  await topUpAllCurrencies(sender, senderSetup.faucetClient);

  // 4. Fetch sender's initial balances
  const senderInitialBalance = await fetchBalance(sender);
  const senderInitialTokens = await fetchSmartAccountCurrencies(sender);
  const recipientInitialBalance = await fetchBalance(recipient);

  // 5. Send NIL currency from sender to recipient
  const sendAmountNIL = convertEthToWei(0.000001);
  await sendCurrency({
    smartAccount: sender,
    to: recipient.address,
    value: 0.00001,
    tokenSymbol: Currency.NIL,
  });

  // 6. Fetch updated balances after NIL transfer
  const senderBalanceAfterNIL = await fetchBalance(sender);
  const recipientBalanceAfterNIL = await fetchBalance(recipient);

  // Check exact balances after transaction
  expect(senderBalanceAfterNIL).toBeLessThan(senderInitialBalance);
  expect(recipientBalanceAfterNIL).toBeGreaterThan(recipientInitialBalance);

  // 7. Send BTC token from sender to recipient
  const sendAmountBTC = 5n;
  const btcTokenAddress = getTokenAddressBySymbol(Currency.BTC);

  await sendCurrency({
    smartAccount: sender,
    to: recipient.address,
    value: Number(sendAmountBTC),
    tokenSymbol: Currency.BTC,
  });

  // 8. Fetch updated token balances
  const senderTokensAfterBTC = await fetchSmartAccountCurrencies(sender);
  const recipientTokensAfterBTC = await fetchSmartAccountCurrencies(recipient);

  // Check exact token balances after transaction
  expect(senderTokensAfterBTC[btcTokenAddress]).toBe(
    senderInitialTokens[btcTokenAddress] - sendAmountBTC,
  );
  expect(recipientTokensAfterBTC[btcTokenAddress]).toBe(sendAmountBTC);
});
