import { ethers } from "ethers";

/**
 * BlockchainDiagnostic provides utilities to diagnose blockchain connection issues
 */
export class BlockchainDiagnostic {
  private provider: ethers.providers.JsonRpcProvider;
  
  constructor(rpcUrl: string = "http://localhost:8545") {
    this.provider = new ethers.providers.JsonRpcProvider(rpcUrl);
  }
  
  /**
   * Performs a comprehensive connection test to diagnose blockchain issues
   */
  public async runDiagnostic(): Promise<{
    success: boolean;
    details: {
      connected: boolean;
      networkInfo?: {
        name: string;
        chainId: number;
      };
      blockNumber?: number;
      accounts?: string[];
      gasPrice?: string;
      latency: number;
    };
    error?: string;
  }> {
    const startTime = Date.now();
    try {
      // Basic connection test
      const network = await this.provider.getNetwork();
      const blockNumber = await this.provider.getBlockNumber();
      const accounts = await this.provider.listAccounts();
      const gasPrice = (await this.provider.getGasPrice()).toString();
      
      const latency = Date.now() - startTime;
      
      console.log("✅ Blockchain diagnostic completed successfully");
      console.log(`Network Name: ${network.name}, Chain ID: ${network.chainId}`);
      console.log(`Current Block: ${blockNumber}`);
      console.log(`Available Accounts: ${accounts.length}`);
      console.log(`Current Gas Price: ${ethers.utils.formatUnits(gasPrice, 'gwei')} gwei`);
      console.log(`Connection Latency: ${latency}ms`);
      
      return {
        success: true,
        details: {
          connected: true,
          networkInfo: {
            name: network.name,
            chainId: network.chainId,
          },
          blockNumber,
          accounts,
          gasPrice,
          latency,
        }
      };
    } catch (error: any) {
      const latency = Date.now() - startTime;
      console.error("❌ Blockchain connection failed:", error.message);
      
      return {
        success: false,
        details: {
          connected: false,
          latency,
        },
        error: error.message,
      };
    }
  }
  
  /**
   * Checks if a specific smart contract is deployed at the given address
   */
  public async checkContract(contractAddress: string): Promise<boolean> {
    try {
      const code = await this.provider.getCode(contractAddress);
      return code !== "0x"; // Contract exists if code is not empty
    } catch (error) {
      console.error("Error checking contract:", error);
      return false;
    }
  }
}

// Helper function to run diagnostic from anywhere in the app
export async function checkBlockchainConnection(rpcUrl?: string): Promise<boolean> {
  try {
    const diagnostic = new BlockchainDiagnostic(rpcUrl);
    const result = await diagnostic.runDiagnostic();
    return result.success;
  } catch (error) {
    console.error("Failed to check blockchain connection:", error);
    return false;
  }
}

export default BlockchainDiagnostic;