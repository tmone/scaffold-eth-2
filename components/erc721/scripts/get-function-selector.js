const { ethers } = require("hardhat");

async function main() {
  // Function signature for mintTo(address,string)
  const functionSignature = "mintTo(address,string)";
  
  // Calculate function selector (first 4 bytes of the keccak256 hash of the function signature)
  const functionSelector = ethers.keccak256(ethers.toUtf8Bytes(functionSignature)).substring(0, 10);
  
  console.log(`Function signature: ${functionSignature}`);
  console.log(`Function selector: ${functionSelector}`);
  
  // Compare with the selector in the error
  const errorSelector = "0x0075a317";
  console.log(`Selector from error: ${errorSelector}`);
  console.log(`Selectors match: ${functionSelector === errorSelector}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });