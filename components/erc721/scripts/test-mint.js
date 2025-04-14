const { ethers } = require("hardhat");

async function main() {
  try {
    console.log("Testing mintTo with tokenURI parameter...");
    
    // Get the deployed Creature contract
    const creatureAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
    const Creature = await ethers.getContractFactory("Creature");
    const creature = await Creature.attach(creatureAddress);
    
    // Get signer
    const [signer] = await ethers.getSigners();
    console.log("Using signer:", signer.address);
    
    // Define the tokenURI
    const tokenURI = "ipfs://test_metadata_uri";
    
    // Test minting
    console.log("Minting a token with URI:", tokenURI);
    const tx = await creature.mintTo(signer.address, tokenURI);
    const receipt = await tx.wait();
    console.log("Transaction successful:", receipt.hash);
    
    console.log("Test completed successfully!");
  } catch (error) {
    console.error("Error testing mintTo:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });