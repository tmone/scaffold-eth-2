const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying ERC721 NFT contracts...");

  try {
    // Deploy the Creature ERC721 contract
    const proxyRegistryAddress = "0xF57B2c51dED3A29e6891aba85459d600256Cf317"; // OpenSea Proxy Registry for Goerli
    
    const CreatureContract = await ethers.getContractFactory("Creature");
    const creature = await CreatureContract.deploy(proxyRegistryAddress);
    
    // With ethers v6, we need to use waitForDeployment() instead of deployed()
    await creature.waitForDeployment();
    
    // And use getAddress() instead of .address
    console.log("Creature ERC721 deployed to:", await creature.getAddress());
    
    // If you need to deploy additional contracts, add them here
    
    console.log("ERC721 deployment completed successfully!");
  } catch (error) {
    console.error("Error deploying ERC721 contracts:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
