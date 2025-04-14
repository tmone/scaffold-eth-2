// This script helps test the NFT minting functionality directly
const ethers = require("ethers");

async function main() {
  try {
    console.log("Testing NFT mint functionality...");
    
    // Connect to local blockchain
    const provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
    console.log("Connected to provider");
    
    // Get account to use
    const accounts = await provider.listAccounts();
    const userAddress = accounts[0];
    console.log("Using account:", userAddress);
    
    // Get signer
    const signer = await provider.getSigner(userAddress);
    
    // Contract address and ABI from NFTCreatorModal
    const contractAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
    const contractABI = [
      "function mintTo(address _to, string memory _tokenURI) public returns (uint256)",
      "function tokenURI(uint256 _tokenId) public view returns (string memory)",
      "function balanceOf(address _owner) external view returns (uint256)",
      "function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256)",
      "function totalSupply() external view returns (uint256)"
    ];
    
    // Create contract instance
    const nftContract = new ethers.Contract(contractAddress, contractABI, signer);
    console.log("Contract instance created");
    
    // Test token URI
    const tokenURI = "ipfs://test_metadata_from_script";
    
    // Mint NFT
    console.log("Attempting to mint NFT with URI:", tokenURI);
    const tx = await nftContract.mintTo(userAddress, tokenURI);
    console.log("Transaction sent:", tx.hash);
    
    // Wait for transaction to be mined
    const receipt = await tx.wait();
    console.log("Transaction mined:", receipt.hash);
    console.log("NFT minted successfully!");
    
  } catch (error) {
    console.error("Error testing NFT mint:", error);
  }
}

main()
  .then(() => console.log("Test completed"))
  .catch(error => console.error("Test failed:", error));