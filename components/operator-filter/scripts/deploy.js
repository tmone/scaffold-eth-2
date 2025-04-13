const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying Operator Filter Registry...");

  try {
    // Deploy OperatorFilterRegistry
    const OperatorFilterRegistry = await ethers.getContractFactory("OperatorFilterRegistry");
    const registry = await OperatorFilterRegistry.deploy();
    await registry.waitForDeployment();
    const registryAddress = await registry.getAddress();
    console.log("OperatorFilterRegistry deployed to:", registryAddress);
    
    console.log("Operator Filter deployment completed successfully!");
    
    return { operatorFilterRegistry: registryAddress };
  } catch (error) {
    console.error("Error deploying Operator Filter Registry:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
