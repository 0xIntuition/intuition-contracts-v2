import { ethers } from "ethers";
import * as dotenv from "dotenv";
dotenv.config();

const BASE_RPC_URL = process.env.BASE_RPC_URL || "";
if (!BASE_RPC_URL) {
  throw new Error("Missing BASE_RPC_URL in .env");
}

async function main() {
  // Constants for the TimelockController and schedule parameters
  const timelockControllerAddress =
    "0xE4992f9805D7737b5bDaDBEF5688087CF25D4B89"; // TimelockController contract address on Base mainnet
  const target = "0xc920E2F5eB6925faE85C69a98a2df6f56a7a245A"; // ProxyAdmin contract address on Base mainnet
  const value = 0;
  const predecessor =
    "0x0000000000000000000000000000000000000000000000000000000000000000";
  const salt =
    "0x0000000000000000000000000000000000000000000000000000000000000000";

  // Reinitialize calldata (can be left empty if no reinitialization call is needed)
  const reinitializeCalldata = process.argv[2]
    ? process.argv[2]
    : "0x459876120000000000000000000000000bb6f224e6055ca90c2f6fd8693e721a3ade9e700000000000000000000000000000000000000000000000000000000000000001";

  // To be replaced with actual values as needed
  const proxy = process.argv[3]
    ? process.argv[3]
    : "0x430BbF52503Bd4801E51182f4cB9f8F534225DE5"; // EthMultiVault proxy contract address on Base mainnet
  const implementation = process.argv[4]
    ? process.argv[4]
    : "0x232a8398b2C29EB6282FD4bbBe3a228B55902515"; // Replace with the actual implementation address you want to upgrade to once it's deployed

  // Validate proxy and implementation addresses are provided and are valid
  if (!proxy || !implementation) {
    throw new Error("Proxy and implementation addresses must be provided.");
  }

  if (
    !ethers.utils.isAddress(proxy) ||
    !ethers.utils.isAddress(implementation)
  ) {
    throw new Error("Invalid proxy or implementation address.");
  }

  // Initialize the provider
  const provider = new ethers.providers.JsonRpcProvider(BASE_RPC_URL);

  // Fetch the minimum delay from the TimelockController contract
  const timelockABI = [
    "function getMinDelay() external view returns (uint256)",
  ];
  const timelockContract = new ethers.Contract(
    timelockControllerAddress,
    timelockABI,
    // @ts-ignore
    provider
  );
  const delay = await timelockContract.getMinDelay();

  // Generate the calldata for the upgradeAndCall function
  const proxyAdminABI = [
    "function upgradeAndCall(address proxy, address implementation, bytes data) external payable",
  ];
  const proxyAdminInterface = new ethers.utils.Interface(proxyAdminABI);
  const data = proxyAdminInterface.encodeFunctionData("upgradeAndCall", [
    proxy,
    implementation,
    reinitializeCalldata,
  ]);

  // Log the schedule parameters
  console.log("Schedule Parameters:\n");
  console.log(`Target: ${target}\n`);
  console.log(`Value: ${value}\n`);
  console.log(`Data: ${data}\n`);
  console.log(`Predecessor: ${predecessor}\n`);
  console.log(`Salt: ${salt}\n`);
  console.log(`Delay: ${delay}\n`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
