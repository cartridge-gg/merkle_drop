#!/usr/bin/env node

import { pad } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { StandardMerkleTree } from "@ericnordelo/strk-merkle-tree";
import { hash, num, selector } from "starknet";

// entry 3 is modified to use custom eth address
// ["0x4884ABe82470adf54f4e19Fa39712384c05112be", [297, 483, 678, 707, 865]],
import snapshot from "./dope.json" assert { type: "json" };
import { CallData } from "starknet";

const main = async () => {
  const pk0 = pad("0x420");
  const account = privateKeyToAccount(pk0);

  const claim_contract_address =
    "0x593dd47498149f98f589a972c947b581f2ab12585eeb1ee041b383ba3fe6974";
  const entrypoint = selector.getSelectorFromName("claim_from_forwarder");

  const snapshot_serialized = snapshot.map((i) => {
    return [i[0], CallData.compile([i[1]])];
  });
  const snapshot_encoded = snapshot_serialized.map((i) => {
    return [
      num.toHex64(
        hash.computePoseidonHashOnElements([
          i[0],
          claim_contract_address,
          entrypoint,
          i[1].length,
          ...i[1],
        ])
      ),
    ];
  });

  const index = snapshot_serialized.findIndex((i) => {
    return BigInt(i[0]) === BigInt(account.address);
  });
  const found = snapshot_serialized[index];

  const hashed = num.toHex64(
    hash.computePoseidonHashOnElements([
      found[0],
      claim_contract_address,
      entrypoint,
      found[1].length,
      ...found[1],
    ])
  );

  const index_hashed = snapshot_encoded.findIndex(
    (i) => BigInt(i) === BigInt(hashed)
  );

  console.log(index);
  console.log(index_hashed);

  const tree = StandardMerkleTree.of(snapshot_encoded, ["felt252"], {
    sortLeaves: true,
  });
  const proof = tree.getProof(index_hashed);
  const leafHash = tree.leafHash(snapshot_encoded[index_hashed]);
  console.log("Merkle Root:", tree.root);
  console.log("Proof:", proof);
  console.log("leaf: ", snapshot_encoded[index_hashed]);
  console.log("leafHash:", leafHash);
  console.log(found);
  const isValid = tree.verify(index_hashed, proof);
  console.log("valid: ", isValid);
};

main();
