import { ethers } from "hardhat";

async function main() {
  // Get the wallet address to fund from command line arguments
  const walletToFund = process.argv[2];
  if (!walletToFund) {
    console.error("Please provide a wallet address to fund");
    process.exit(1);
  }

  // Amount to fund (100 ETH)
  const fundAmount = ethers.parseEther("100");

  // Get the first account (which has plenty of ETH in hardhat)
  const [deployer] = await ethers.getSigners();
  
  console.log(`Funding wallet ${walletToFund} with 100 ETH from ${deployer.address}`);
  
  // Send the transaction
  const tx = await deployer.sendTransaction({
    to: walletToFund,
    value: fundAmount
  });
  
  // Wait for the transaction to be mined
  await tx.wait();
  
  console.log(`Successfully funded ${walletToFund}`);
  console.log(`Transaction hash: ${tx.hash}`);
}

// Execute the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });