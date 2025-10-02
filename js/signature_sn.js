#!/usr/bin/env node
import {
  constants,
  TypedDataRevision,
  ec,
  stark,
  Signer,
  Account,
  typedData,
} from "starknet";

const main = async () => {
  const myTypedData = {
    domain: {
      name: "Merkle Drop",
      chainId: constants.StarknetChainId.SN_SEPOLIA,
      version: "1",
      revision: TypedDataRevision.ACTIVE,
    },
    primaryType: "Claim",
    types: {
      StarknetDomain: [
        {
          name: "name",
          type: "shortstring",
        },
        {
          name: "version",
          type: "shortstring",
        },
        {
          name: "chainId",
          type: "shortstring",
        },
        {
          name: "revision",
          type: "shortstring",
        },
      ],
      Claim: [
        {
          name: "recipient",
          type: "ContractAddress",
        },
      ],
    },
    message: {
      recipient:
        "0x9aa528ac622ad7cf637e5b8226f465da1080c81a2daeb37a97ee6246ae2301",
    },
  };

  const privateKey = "0x420";
  const starknetPublicKey = ec.starkCurve.getStarkKey(privateKey);

  console.log("starknetPublicKey", starknetPublicKey);

  const accountAddress =
    "0x4ce00ffd9b927a25b31291371af851a6d242c18c4e1668dd224484d4a09d556"; // SnAccount
  const signer = new Signer(privateKey);

  const typeHash = typedData.getTypeHash(myTypedData.types, "Claim", 1);
  const msgHash = typedData.getMessageHash(myTypedData, accountAddress);
  const signature = await signer.signMessage(myTypedData, accountAddress);

  console.log("typeHash", typeHash);
  console.log("msgHash", msgHash);
  console.log("signature", signature);
};

main();
