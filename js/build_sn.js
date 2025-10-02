#!/usr/bin/env node

import { pad } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { CallData, ec, stark } from "starknet";
import fs from "node:fs";
import { hash, num, selector } from "starknet";

import snapshot from "./snapshots/dope-22728943.json" assert { type: "json" };

const randomStarknetAddress = (seed) => {
  return ec.starkCurve.getStarkKey(hash.computeHashOnElements([seed]));
};

const main = async () => {
  // replace all eth addresses by random sn addresses
  snapshot.snapshot = snapshot.snapshot.map((i) => {
    i[0] = randomStarknetAddress(i[0]);
    return i;
  });

  // replace entrypoint
  snapshot.entrypoint = "claim_from_forwarder_with_extra_data";

  // replace network
  snapshot.network = "STARKNET";

  // #[derive(Drop, Copy, Clone, Serde, PartialEq)]
  // pub struct LeafDataWithExtraData {
  //     pub amount_A: u32,
  //     pub amount_B: u32,
  //     pub token_ids: Span<felt252>,
  // }

  // add extra data && compile calldata
  snapshot.snapshot = snapshot.snapshot.map((i) => {
    const token_ids = i[1];
    const amount_A = token_ids.length;
    const amount_B = Math.ceil(token_ids.length / 2);
    return [i[0], "0", CallData.compile([amount_A, amount_B, token_ids])];
  });

  // fs.writeFileSync(
  //   "./snapshots/dope-22728943-sn.json",
  //   JSON.stringify(snapshot, null, 2)
  // );
};

main();
