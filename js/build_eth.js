#!/usr/bin/env node

import { pad } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import fs from "node:fs";

import snapshot from "./snapshots/dope-22728943.json" assert { type: "json" };
import { CallData } from "starknet";

const main = async () => {
  const pk0 = pad("0x420");
  const account = privateKeyToAccount(pk0);

  // replace address at index 2 by our address
  // ["0x0154d25120ed20a516fe43991702e7463c5a6f6e", [21, 207, 295, 472, 570, 900, 943, 974]]
  snapshot.snapshot[2][0] = account.address;

  // compile calldata
  snapshot.snapshot = snapshot.snapshot.map((i) => {
    return [i[0], CallData.compile([i[1]])];
  });

  fs.writeFileSync(
    "./snapshots/dope-22728943-eth.json",
    JSON.stringify(snapshot, null, 2)
  );
};

main();
