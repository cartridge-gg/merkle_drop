
import { hash, num, selector } from "starknet";

export const hashLeaf = (leaf, claim_contract, entrypoint) => {
  return num.toHex64(
    hash.computePoseidonHashOnElements([
      leaf[0], // address
      leaf[1], // index
      claim_contract,
      selector.getSelectorFromName(entrypoint),
      leaf[2].length, // leaf_data len
      ...leaf[2], // leaf_data values
    ])
  );
};