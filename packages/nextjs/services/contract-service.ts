/**
 * Contract service for managing contract addresses
 * Provides functions to fetch and update contract addresses
 */

// Default fallback addresses in case API fails
const FALLBACK_ADDRESSES = {
  local: {
    Creature: "0x851356ae760d987E095750cCeb3bC6014560891C",
  },
  testnet: {
    Creature: "",
  },
  mainnet: {
    Creature: "",
  },
};

/**
 * Get the contract address for a specific contract on a network
 * 
 * @param contractName - Name of the contract
 * @param network - Network name (local, testnet, mainnet)
 * @returns Contract address
 */
export async function getContractAddress(contractName: string, network: string = "local"): Promise<string> {
  try {
    const response = await fetch(`/api/contracts?network=${network}&contractName=${contractName}`);
    
    if (!response.ok) {
      throw new Error(`Failed to fetch contract address: ${response.statusText}`);
    }
    
    const data = await response.json();
    
    if (!data.address) {
      console.warn(`No address found for ${contractName} on ${network}, using fallback`);
      return FALLBACK_ADDRESSES[network as keyof typeof FALLBACK_ADDRESSES]?.[contractName] || "";
    }
    
    return data.address;
  } catch (error) {
    console.error("Error fetching contract address:", error);
    return FALLBACK_ADDRESSES[network as keyof typeof FALLBACK_ADDRESSES]?.[contractName] || "";
  }
}

/**
 * Get all contract addresses for a specific network
 * 
 * @param network - Network name (local, testnet, mainnet)
 * @returns Object with contract addresses
 */
export async function getAllContractAddresses(network: string = "local"): Promise<Record<string, string>> {
  try {
    const response = await fetch(`/api/contracts?network=${network}`);
    
    if (!response.ok) {
      throw new Error(`Failed to fetch contract addresses: ${response.statusText}`);
    }
    
    const data = await response.json();
    return data.addresses || {};
  } catch (error) {
    console.error("Error fetching all contract addresses:", error);
    return FALLBACK_ADDRESSES[network as keyof typeof FALLBACK_ADDRESSES] || {};
  }
}

/**
 * Update a contract address in the database
 * 
 * @param contractName - Name of the contract
 * @param address - New contract address
 * @param network - Network name (local, testnet, mainnet)
 * @returns Boolean indicating success/failure
 */
export async function updateContractAddress(
  contractName: string, 
  address: string, 
  network: string = "local"
): Promise<boolean> {
  try {
    const response = await fetch("/api/contracts", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        network,
        contractName,
        address,
      }),
    });
    
    if (!response.ok) {
      throw new Error(`Failed to update contract address: ${response.statusText}`);
    }
    
    const data = await response.json();
    return data.success === true;
  } catch (error) {
    console.error("Error updating contract address:", error);
    return false;
  }
}