import { ethers } from "ethers";

async function main() {
  // Constants for the TimelockController and schedule parameters
  const timelockControllerAddress = "0xE4992f9805D7737b5bDaDBEF5688087CF25D4B89"; // Target TimelockController contract address
  const target = ""; // Target ProxyAdmin contract address
  const value = 0;
  const predecessor = "0x0000000000000000000000000000000000000000000000000000000000000000";
  const salt = "0x0000000000000000000000000000000000000000000000000000000000000000";

  if (!ethers.utils.isAddress(timelockControllerAddress) || !ethers.utils.isAddress(target)) {
    throw new Error("Invalid TimelockController or ProxyAdmin (target) address.");
  }

  const rpcUrl = process.argv[2];

  // Parse proxy and new implementation addresses from command line arguments (e.g. "0xProxyAddress,0xNewImplementationAddress")
  const proxyAndNewImpl = process.argv[3];
  const [proxy, implementation] = proxyAndNewImpl.split(",");

  // Reinitialize calldata (can be left empty if no reinitialization call is needed)
  const reinitializeCalldata = process.argv[4];

  // Validate proxy and implementation addresses are provided and are valid
  if (!proxy || !implementation) {
    throw new Error("Proxy and implementation addresses must be provided.");
  }

  if (!ethers.utils.isAddress(proxy) || !ethers.utils.isAddress(implementation)) {
    throw new Error("Invalid proxy or implementation address.");
  }

  // Initialize the provider
  const provider = new ethers.providers.JsonRpcProvider(rpcUrl);

  // Fetch the minimum delay from the TimelockController contract
  const timelockABI = ["function getMinDelay() external view returns (uint256)"];
  const timelockContract = new ethers.Contract(timelockControllerAddress, timelockABI, provider);
  const delay = await timelockContract.getMinDelay();

  // Generate the calldata for the upgradeAndCall function
  const proxyAdminABI = ["function upgradeAndCall(address proxy, address implementation, bytes data) external payable"];
  const proxyAdminInterface = new ethers.utils.Interface(proxyAdminABI);
  const data = proxyAdminInterface.encodeFunctionData("upgradeAndCall", [proxy, implementation, reinitializeCalldata]);

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
