const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("Starting contract redeployment process...");

  // Get the contract factory
  const Creature = await ethers.getContractFactory("Creature");
  
  console.log("Deploying new Creature contract...");
  
  // Deploy the contract with a zero address as the proxy registry
  // You might need to replace this with a real proxy registry if needed
  const zeroAddress = "0x0000000000000000000000000000000000000000";
  
  // In newer versions of Hardhat, deploy() directly returns the deployed contract
  const creature = await Creature.deploy(zeroAddress);
  
  // Wait for the deployment transaction to be mined
  await creature.deploymentTransaction().wait();
  
  const contractAddress = await creature.getAddress();
  console.log("Creature deployed to:", contractAddress);
  console.log("Deployment transaction hash:", creature.deploymentTransaction().hash);
  
  // Log some important contract information
  const name = await creature.name();
  const symbol = await creature.symbol();
  const owner = await creature.owner();
  
  console.log(`Name: ${name}`);
  console.log(`Symbol: ${symbol}`);
  console.log(`Owner: ${owner}`);
  
  // Save the contract address to the addresses.json file
  await updateAddressesFile("Creature", contractAddress);
  
  console.log(`\nNOTE: Contract address has been updated in the addresses.json file.`);
  console.log(`Next.js will use this address automatically on restart.`);
}

async function updateAddressesFile(contractName, address) {
  try {
    // Path to the addresses.json file in the Next.js app
    const addressesPath = path.join(__dirname, "../../../packages/nextjs/contracts/addresses.json");
    
    // Check if the file exists
    let addressesData = {
      local: {},
      testnet: {},
      mainnet: {}
    };
    
    if (fs.existsSync(addressesPath)) {
      // Read the current addresses.json file
      const fileData = fs.readFileSync(addressesPath, "utf8");
      addressesData = JSON.parse(fileData);
    }
    
    // Update the address for the contract
    if (!addressesData.local) {
      addressesData.local = {};
    }
    
    addressesData.local[contractName] = address;
    
    // Write back to the file
    fs.writeFileSync(addressesPath, JSON.stringify(addressesData, null, 2));
    
    console.log(`Updated ${contractName} address in addresses.json: ${address}`);
    return true;
  } catch (error) {
    console.error("Error updating addresses.json file:", error);
    return false;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });