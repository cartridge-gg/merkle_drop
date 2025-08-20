#!/usr/bin/env node

import { hashMessage, pad, parseSignature, verifyMessage } from "viem";
import { privateKeyToAccount } from "viem/accounts";

const main = async () => {
  const pk0 = pad("0x420");
  const account = privateKeyToAccount(pk0);

  const message0 = "Claim on starknet with: 0x123456789abcdef"
  const message0Hash = hashMessage(message0);
  console.log("message0Hash", message0Hash)

  const message = `Claim on starknet with: 0x7db9cc4a5e5485becbde0c40e71af59d72c543dea4cdeddf3c54ba03fdf14eb`;
  const messageHash = hashMessage(message);

  const signature = await account.signMessage({
    message,
  });

  const parsedSignature = parseSignature(signature);

  console.log("ETH address: ", account.address)
  console.log("message: ");
  console.log(message)
  console.log("------------");
  console.log("messageHash: ", messageHash);
  console.log("signature: ", signature);
  console.log("parsedSignature: ", parsedSignature);

  const isValid = await verifyMessage({
    address: account.address,
    message,
    signature,
  });

  console.log("isValid", isValid);
};

main();
