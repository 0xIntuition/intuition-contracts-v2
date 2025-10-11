import { ethers } from "ethers";

async function main() {
  const target = "0x857552ab95E6cC389b977d5fEf971DEde8683e8e"; // ProxyAdmin for Trust contract address

  if (!ethers.utils.isAddress(target)) {
    throw new Error("Invalid ProxyAdmin (target) address.");
  }

  const proxy = process.argv[2];
  const implementation = process.argv[3];
  const reinitializeCalldata = process.argv[4];

  // Validate proxy and implementation addresses are provided and are valid
  if (!proxy || !implementation) {
    throw new Error("Proxy and implementation addresses must be provided.");
  }

  if (!ethers.utils.isAddress(proxy) || !ethers.utils.isAddress(implementation)) {
    throw new Error("Invalid proxy or implementation address.");
  }

  // Generate the calldata for the upgradeAndCall function
  const proxyAdminABI = ["function upgradeAndCall(address proxy, address implementation, bytes data) external payable"];
  const proxyAdminInterface = new ethers.utils.Interface(proxyAdminABI);
  const data = proxyAdminInterface.encodeFunctionData("upgradeAndCall", [proxy, implementation, reinitializeCalldata]);

  console.log(`Calldata:\n ${data}\n`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
