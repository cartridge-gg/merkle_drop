#!/usr/bin/env node

import { pad } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { StandardMerkleTree } from "@ericnordelo/strk-merkle-tree";
import { hashLeaf } from "./hash_leaf.js";
import fs from "node:fs";

const pk0 = pad("0x420");
const account = privateKeyToAccount(pk0);


const main = async () => {
  const snapshotPath = process.argv[2];
  const address = process.argv[3] || account.address;
  const claimIndex = process.argv[4] || 0;

  console.log("address: ", address)

  if (!snapshotPath) {
    console.log("missing arg[0] snapshot_path");
    return;
  }
  const snapshot = JSON.parse(fs.readFileSync(snapshotPath));
  const snapshotHashed = snapshot.snapshot.map((i) => {
    return [hashLeaf(i, snapshot.claim_contract, snapshot.entrypoint)];
  });

  const index = snapshot.snapshot.findIndex((i) => {
    return BigInt(i[0]) === BigInt(address) && BigInt(i[1]) === BigInt(claimIndex);
  });
  const found = snapshot.snapshot[index];

  const hashed = hashLeaf(found, snapshot.claim_contract, snapshot.entrypoint);
  const indexHashed = snapshotHashed.findIndex(
    (i) => BigInt(i) === BigInt(hashed)
  );

  console.log(index);
  console.log(indexHashed);

  const tree = StandardMerkleTree.of(snapshotHashed, ["felt252"], {
    sortLeaves: true,
  });
  const proof = tree.getProof(indexHashed);
  const leafHash = tree.leafHash(snapshotHashed[indexHashed]);
  console.log("Merkle Root:", tree.root);
  console.log("Proof:", proof);
  console.log("leaf: ", snapshotHashed[indexHashed]);
  console.log("leafHash:", leafHash);
  console.log(found);
  const isValid = tree.verify(indexHashed, proof);
  console.log("valid: ", isValid);

  // fs.writeFileSync(
  //   "./snapshots/dope-22728943-eth-tree.json",
  //   JSON.stringify(tree.dump(), null, 2)
  // );
};

main();
