import { ethers } from "ethers";

async function main() {
  // Constants for the TimelockController and schedule parameters
  const timelockControllerAddress = "0x1E442BbB08c98100b18fa830a88E8A57b5dF9157"; // Target TimelockController contract address
  const target = timelockControllerAddress; // TimelockController itself is the target when updating min delay
  const value = 0;
  const predecessor = "0x0000000000000000000000000000000000000000000000000000000000000000";
  const salt = "0x0000000000000000000000000000000000000000000000000000000000000000";

  if (!ethers.utils.isAddress(timelockControllerAddress)) {
    throw new Error("Invalid TimelockController address.");
  }

  const rpcUrl = process.argv[2];

  // Initialize the provider
  const provider = new ethers.providers.JsonRpcProvider(rpcUrl);

  // Fetch the minimum delay from the TimelockController contract
  const timelockABI = [
    "function getMinDelay() external view returns (uint256)",
    "function updateDelay(uint256 newDelay) external",
  ];
  const timelockContract = new ethers.Contract(timelockControllerAddress, timelockABI, provider);
  const currentDelay = await timelockContract.getMinDelay();

  const newDelayInSeconds = parseInt(process.argv[3]);

  if (isNaN(newDelayInSeconds) || newDelayInSeconds <= Number(currentDelay)) {
    throw new Error("A valid delay in seconds must be provided.");
  }

  // Generate the calldata for the updateDelay function
  const proxyAdminInterface = new ethers.utils.Interface(timelockABI);
  const data = proxyAdminInterface.encodeFunctionData("updateDelay", [newDelayInSeconds]);

  // Log the schedule parameters
  console.log("Schedule Parameters:\n");
  console.log(`Target: ${target}\n`);
  console.log(`Value: ${value}\n`);
  console.log(`Data: ${data}\n`);
  console.log(`Predecessor: ${predecessor}\n`);
  console.log(`Salt: ${salt}\n`);
  console.log(`Delay: ${currentDelay}\n`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
