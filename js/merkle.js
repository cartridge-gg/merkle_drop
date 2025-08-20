#!/usr/bin/env node

import { pad } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import {
  SimpleMerkleTree,
  StandardMerkleTree,
} from "@ericnordelo/strk-merkle-tree";
import { hash, num, selector } from "starknet";
import fs from "fs";

// entry 3 is modified to use custom eth address
// ["0x4884ABe82470adf54f4e19Fa39712384c05112be", [297, 483, 678, 707, 865]],
import snapshot from "./dope.json" assert { type: "json" };

const main = async () => {
  const pk0 = pad("0x420");
  const account = privateKeyToAccount(pk0);

  const claim_contract_address =
    "0x2803f7953e7403d204906467e2458ca4b206723607acae26c9c729a926e491f";
  const entrypoint = selector.getSelectorFromName("claim_from_forwarder");

  const snapshot_encoded = snapshot.map((i) => {
    return num.toHex64(
      hash.computePoseidonHashOnElements([
        i[0],
        claim_contract_address,
        entrypoint,
        i[1].length,
        ...i[1],
      ])
    );
  });

  const index = snapshot.findIndex((i) => {
    return BigInt(i[0]) === BigInt(account.address);
  });
  const found = snapshot[index];
  const hashed = num.toHex64(
    hash.computePoseidonHashOnElements([
      found[0],
      claim_contract_address,
      entrypoint,
      found[1].length,
      ...found[1],
    ])
  );

  const index_hashed = snapshot_encoded.findIndex(i => i === hashed)

  // console.log(snapshot_encoded);
  // console.log(account.address);
  console.log(index);
  console.log(index_hashed);

  const tree = SimpleMerkleTree.of(snapshot_encoded, {sortLeaves:false});
  // const tree = StandardMerkleTree.of(snapshot_encoded, ["felt252"]);
  const proof = tree.getProof(index_hashed);
  const leafHash = tree.leafHash(snapshot_encoded[index_hashed]);
  console.log("Merkle Root:", tree.root);
  console.log("Proof:", proof);
  console.log("leaf: ", snapshot_encoded[index_hashed]);
  console.log("leafHash:", leafHash);

  const isValid = tree.verify(index_hashed, proof);
  console.log("valid: ", isValid);
};

main();
