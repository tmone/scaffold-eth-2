const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying ERC1155 NFT contracts...");

  try {
    // Deploy ModernERC1155
    const ModernERC1155 = await ethers.getContractFactory("ModernERC1155");
    const modernERC1155 = await ModernERC1155.deploy(
      "OpenSea QC NFT Collection",
      "OSQC",
      "https://api.opensea-qc.test/api/token/{id}"
    );
    await modernERC1155.waitForDeployment();
    const nftAddress = await modernERC1155.getAddress();
    console.log("ModernERC1155 deployed to:", nftAddress);

    console.log("ERC1155 deployment completed successfully!");
    
    return { modernERC1155: nftAddress };
  } catch (error) {
    console.error("Error deploying ERC1155 contracts:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
