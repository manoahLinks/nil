import type { Hex } from "@nilfoundation/niljs";
import { Button, COLORS, FormControl, Input, LabelSmall, SPACE } from "@nilfoundation/ui-kit";
import { INPUT_KIND, INPUT_SIZE } from "@nilfoundation/ui-kit";
import type { InputOverrides } from "baseui/input";
import { useUnit } from "effector-react";
import { useCallback, useEffect, useState } from "react";
import { useStyletron } from "styletron-react";
import { $smartAccount } from "../../../account-connector/model";
import {
  $activeAppWithState,
  $assignedSmartContractAddress,
  $deployedContracts,
  assignSmartContract,
  assignSmartContractFx,
  setAssignedSmartContractAddress,
} from "../../models/base";

export const ImportContractTab = () => {
  const [smartAccount, pending, deployedContracts, assignedAddress, activeApp] = useUnit([
    $smartAccount,
    assignSmartContractFx.pending,
    $deployedContracts,
    $assignedSmartContractAddress,
    $activeAppWithState,
  ]);

  const [css] = useStyletron();
  const [error, setError] = useState<string | null>(null);

  const validateAddress = useCallback(
    (address: string) => {
      if (!address || address === "0x") {
        setError(null);
        return;
      }
      const existingAddresses = Object.values(deployedContracts).flat();
      if (existingAddresses.includes(address)) {
        setError(`Contract with address ${address} already exists.`);
      } else {
        setError(null);
      }
    },
    [deployedContracts],
  );

  useEffect(() => {
    validateAddress(assignedAddress);
  }, [assignedAddress, validateAddress]);

  useEffect(() => {
    setAssignedSmartContractAddress("0x" as Hex);
    setError(null);
  }, []);

  return (
    <>
      <div
        className={css({
          flexGrow: 0,
          paddingBottom: SPACE[16],
        })}
      >
        <FormControl label="Address">
          <Input
            kind={INPUT_KIND.secondary}
            size={INPUT_SIZE.small}
            overrides={inputOverrides}
            onChange={(e) => {
              const value = e.target.value as Hex;
              setAssignedSmartContractAddress(value);
            }}
            value={assignedAddress && assignedAddress !== "0x" ? assignedAddress : ""}
          />
        </FormControl>
        {error && (
          <LabelSmall
            className={css({
              color: COLORS.red500,
              marginTop: SPACE[4],
            })}
          >
            {error}
          </LabelSmall>
        )}
        <LabelSmall
          className={css({
            color: COLORS.gray400,
            marginTop: SPACE[4],
          })}
        >
          Import the already deployed {activeApp?.name} smart contract using its address.
        </LabelSmall>
      </div>
      <div>
        <Button
          onClick={() => {
            if (!error) assignSmartContract();
          }}
          isLoading={pending}
          disabled={pending || !smartAccount || !!error}
        >
          Import
        </Button>
      </div>
    </>
  );
};

const inputOverrides: InputOverrides = {
  Root: {
    style: () => ({
      background: COLORS.gray700,
      ":hover": {
        background: COLORS.gray600,
      },
    }),
  },
};
