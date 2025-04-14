const { ethers } = require("hardhat");

async function main() {
  try {
    // Get the contract at the deployed address
    const contractAddress = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0";
    const Creature = await ethers.getContractFactory("Creature");
    const creature = await Creature.attach(contractAddress);
    
    console.log("Connected to deployed contract at:", contractAddress);
    
    // Get a signer
    const [deployer] = await ethers.getSigners();
    console.log("Using signer:", deployer.address);
    
    // Test minting an NFT with a token URI
    const tokenURI = "ipfs://test_verification_uri";
    console.log("Attempting to mint with tokenURI:", tokenURI);
    
    const tx = await creature.mintTo(deployer.address, tokenURI);
    console.log("Transaction sent:", tx.hash);
    
    const receipt = await tx.wait();
    console.log("Transaction confirmed:", receipt.hash);
    console.log("Gas used:", receipt.gasUsed.toString());
    
    console.log("Minting successful!");
    
  } catch (error) {
    console.error("Error testing contract:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });