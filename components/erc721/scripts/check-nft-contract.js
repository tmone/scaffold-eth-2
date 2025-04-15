const { ethers } = require("hardhat");

async function main() {
  console.log("Checking NFT contract and accounts on local network");

  // Get all accounts
  const accounts = await ethers.getSigners();
  console.log("Available accounts:");
  accounts.forEach((account, i) => {
    console.log(`[${i}] ${account.address}`);
  });

  // Connect to the Creature contract
  const contractAddress = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
  const creatureABI = [
    "function owner() view returns (address)",
    "function mintTo(address _to, string memory _tokenURI) returns (uint256)",
    "function name() view returns (string)",
    "function symbol() view returns (string)",
    "function totalSupply() view returns (uint256)"
  ];

  try {
    // Connect to contract with provider
    const provider = ethers.provider;
    const contract = new ethers.Contract(contractAddress, creatureABI, provider);
    
    // Basic contract info
    console.log("\nContract Information:");
    try {
      const name = await contract.name();
      const symbol = await contract.symbol();
      const totalSupply = await contract.totalSupply();
      console.log(`Name: ${name}`);
      console.log(`Symbol: ${symbol}`);
      console.log(`Total Supply: ${totalSupply.toString()}`);
    } catch (error) {
      console.log("Error fetching contract info:", error.message);
    }
    
    // Check contract owner
    try {
      const owner = await contract.owner();
      console.log(`Contract owner: ${owner}`);
      console.log(`First account is owner: ${owner.toLowerCase() === accounts[0].address.toLowerCase()}`);
    } catch (error) {
      console.log("Error getting contract owner:", error.message);
    }
    
    // Test minting with the deployer account (first account)
    console.log("\nAttempting to mint NFT with deployer account...");
    try {
      const tx = await contract.connect(accounts[0]).mintTo(
        accounts[1].address, 
        "ipfs://test_metadata_uri"
      );
      console.log(`Transaction hash: ${tx.hash}`);
      const receipt = await tx.wait();
      console.log("Minting successful!");
    } catch (error) {
      console.log("Minting with deployer failed:", error.message);
    }
    
  } catch (error) {
    console.log("Error connecting to contract:", error.message);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });