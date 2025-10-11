import { ethers } from "ethers";

async function main() {
  const trustTokenABI = ["function reinitialize(address _admin, address _baseEmissionsController) external"];
  const admin = process.argv[2];
  const baseEmissionsController = process.argv[3];

  if (!admin || !baseEmissionsController) {
    throw new Error("Admin and base emissions controller addresses must be provided.");
  }
  if (!ethers.utils.isAddress(admin) || !ethers.utils.isAddress(baseEmissionsController)) {
    throw new Error("Invalid admin or base emissions controller address.");
  }

  const trustTokenInterface = new ethers.utils.Interface(trustTokenABI);

  const reinitializeCalldata = trustTokenInterface.encodeFunctionData("reinitialize", [admin, baseEmissionsController]);

  console.log(`Calldata:\n ${reinitializeCalldata}\n`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
