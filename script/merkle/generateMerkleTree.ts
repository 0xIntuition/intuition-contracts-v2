import { ethers } from "ethers";
import { MerkleTree } from "merkletreejs";
import keccak256 from "keccak256";
import fs from "fs";

// Sample allocations
const allocations = [
  {
    account: "0x19711CD19e609FEBdBF607960220898268B7E24b",
    amount: ethers.utils.parseEther("100").toString(),
  },
  {
    account: "0x9A2d18EaF0D3120a3D196C26093020F3a17406e9",
    amount: ethers.utils.parseEther("100").toString(),
  },
  {
    account: "0x5Ee4df0596E527Fd7a7C1059639e6cad483DcEc0",
    amount: ethers.utils.parseEther("100").toString(),
  },
  {
    account: "0xe1Bbf68e5e5745f6C3063562fF35E8769fa3a85b",
    amount: ethers.utils.parseEther("100").toString(),
  },
  {
    account: "0x61D0ef4BE9e8A14793001Ad33258383Dd48618d8",
    amount: ethers.utils.parseEther("100").toString(),
  },
  {
    account: "0x93166cEdbF2aa5CD0b84D4176f8ee64308Df9888",
    amount: ethers.utils.parseEther("100").toString(),
  },
  {
    account: "0x88D0aF73508452c1a453356b3Fac26525aEc23A2",
    amount: ethers.utils.parseEther("100").toString(),
  },
  {
    account: "0xB95ca3D3144e9d1DAFF0EE3d35a4488A4A5C9Fc5",
    amount: ethers.utils.parseEther("100").toString(),
  },
  {
    account: "0xBb285b543C96C927FC320Fb28524899C2C90806C",
    amount: ethers.utils.parseEther("100").toString(),
  },
  {
    account: "0xf0e471d6e8b2f607b6372feca8e0daf73df18f41",
    amount: ethers.utils.parseEther("100").toString(),
  },
  {
    account: "0xb8e3452e62b45e654a300a296061597e3cf3e039",
    amount: ethers.utils.parseEther("100").toString(),
  },
];

// Generate leaf nodes
const elements = allocations.map(({ account, amount }) =>
  keccak256(
    ethers.utils.solidityPack(["address", "uint256"], [account, amount])
  )
);

const merkleTree = new MerkleTree(elements, keccak256, { sortPairs: true });
const merkleRoot = merkleTree.getHexRoot();

// Provide merkle proofs for each user
function getMerkleProof(index: number): string[] {
  const leaf = elements[index];
  return merkleTree.getHexProof(leaf);
}

const filePath = __dirname + "/merkleProofs.json";

// Save the Merkle root and proofs to a JSON file
const merkleData = {
  merkleRoot,
  allocations: allocations.map((allocation, index) => ({
    ...allocation,
    proof: getMerkleProof(index),
  })),
};

// Write the JSON data to a file
fs.writeFileSync(filePath, JSON.stringify(merkleData, null, 2), "utf8");
