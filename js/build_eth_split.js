#!/usr/bin/env node

import { pad } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import fs from "node:fs";

import snapshot from "./snapshots/dope-22728943.json" assert { type: "json" };
import { CallData } from "starknet";

const chunkSize = 5;

const main = async () => {
  const pk0 = pad("0x420");
  const account = privateKeyToAccount(pk0);

  // replace address at index 2 by our address
  // ["0x0154d25120ed20a516fe43991702e7463c5a6f6e", [21, 207, 295, 472, 570, 900, 943, 974]]
  snapshot.snapshot[2][0] = account.address;

  //split & compile calldata
  snapshot.snapshot = snapshot.snapshot.flatMap((item) => {
    if (item[1].length > chunkSize) {
      // split by chunksize
      const chunks = [];
      for (let i = 0; i < item[1].length; i += chunkSize) {
        const chunk = item[1].slice(i, i + chunkSize);
        chunks.push([
          item[0],
          chunks.length.toString(),
          CallData.compile([chunk]),
        ]);
      }
      return chunks;
    } else {
      return [[item[0], "0", CallData.compile([item[1]])]];
    }
  });

  fs.writeFileSync(
    "./snapshots/dope-22728943-eth-split.json",
    JSON.stringify(snapshot, null, 2)
  );
};

main();
