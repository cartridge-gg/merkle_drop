
import { hash, num, selector } from "starknet";

export const hashLeaf = (leaf, claim_contract, entrypoint) => {
  return num.toHex64(
    hash.computePoseidonHashOnElements([
      leaf[0],
      claim_contract,
      selector.getSelectorFromName(entrypoint),
      leaf[1].length,
      ...leaf[1],
    ])
  );
};