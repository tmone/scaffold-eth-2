import { useState, useEffect } from 'react';
import { ethers } from 'ethers';

interface BlockchainStatus {
  isRunning: boolean;
  networkType: string;
  message: string;
  severity: "info" | "warning" | "error";
  timestamp?: number;
  apiEndpoint?: string;
  lastRefresh?: number;
  timeoutMs?: number;
  retries?: number;
}

/**
 * Custom hook to check blockchain status with improved timeout handling
 */
export const useBlockchainStatus = () => {
  const [status, setStatus] = useState<BlockchainStatus>({
    isRunning: false,
    networkType: 'unknown',
    message: 'Checking blockchain status...',
    severity: 'info',
  });
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);
  const [localDatabaseOnly, setLocalDatabaseOnly] = useState(false);
  const [networkInfo, setNetworkInfo] = useState<any>(null);

  const checkConnection = async () => {
    try {
      setIsLoading(true);
      setError(null);

      // If using local database only mode, skip blockchain checks
      if (localDatabaseOnly) {
        return false;
      }

      // First try to fetch from public/network-status.json which is updated by the start-ui.sh script
      try {
        const timestamp = Date.now();
        const response = await fetch(`/network-status.json?t=${timestamp}`, {
          cache: 'no-store',
          headers: {
            'Cache-Control': 'no-cache',
          },
        });
        
        if (response.ok) {
          const data = await response.json();
          setStatus(data);
          // Sync the isRunning property to match expected interface
          if (data.isRunning) {
            setNetworkInfo({
              name: data.networkType,
              chainId: 31337, // Hardhat's default chain ID
              blockNumber: undefined // We don't have this from the JSON file
            });
          }
          setIsLoading(false);
          return data.isRunning;
        }
      } catch (fetchError) {
        console.warn("Could not fetch network status file, falling back to direct RPC check");
      }

      // If file fetch fails, check RPC directly with improved timeout handling
      const RPC_URL = process.env.NEXT_PUBLIC_LOCAL_RPC_URL || 'http://localhost:8545';
      const TIMEOUT = parseInt(process.env.NEXT_PUBLIC_NETWORK_TIMEOUT || '30000');
      const MAX_RETRIES = parseInt(process.env.NEXT_PUBLIC_NETWORK_RETRIES || '3');
      
      console.log(`Checking blockchain at ${RPC_URL} with ${TIMEOUT}ms timeout, ${MAX_RETRIES} retries...`);

      // Create a timeout promise
      const timeoutPromise = new Promise((_, reject) => {
        setTimeout(() => reject(new Error(`Network request timeout after ${TIMEOUT / 1000} seconds`)), TIMEOUT);
      });

      // Create RPC check function with retries
      const checkRpc = async (retries: number): Promise<{success: boolean, network?: ethers.providers.Network, blockNumber?: number}> => {
        try {
          if (retries <= 0) {
            throw new Error("Max retries exceeded");
          }

          const provider = new ethers.providers.JsonRpcProvider(RPC_URL);
          provider.pollingInterval = 10000; // Longer polling interval
          
          // Race against timeout
          const network = await Promise.race([
            provider.getNetwork(),
            timeoutPromise
          ]) as ethers.providers.Network;
          
          // Try to get block number if network connection worked
          let blockNumber;
          try {
            blockNumber = await provider.getBlockNumber();
          } catch (blockErr) {
            console.warn("Could not get block number:", blockErr);
          }
          
          console.log("Connected to network:", network, "Block number:", blockNumber);
          return { success: true, network, blockNumber };
        } catch (error) {
          console.warn(`RPC check attempt failed (${MAX_RETRIES - retries + 1}/${MAX_RETRIES})`, error);
          if (retries > 1) {
            // Wait before retry with exponential backoff
            const backoffTime = parseInt(process.env.NEXT_PUBLIC_RETRY_BACKOFF || '2000');
            await new Promise(resolve => setTimeout(resolve, backoffTime));
            return checkRpc(retries - 1);
          }
          return { success: false };
        }
      };

      // Try to connect with retries
      const result = await checkRpc(MAX_RETRIES);
      
      if (result.success) {
        setStatus({
          isRunning: true,
          networkType: result.network?.name || 'local',
          message: 'Connected to local Hardhat network',
          severity: 'info',
          timestamp: Date.now(),
          timeoutMs: TIMEOUT,
          retries: MAX_RETRIES
        });

        // Set network info for the UI to show
        if (result.network) {
          setNetworkInfo({
            name: result.network.name || 'unknown',
            chainId: result.network.chainId,
            blockNumber: result.blockNumber
          });
        }
        
        return true;
      } else {
        throw new Error("Could not connect to blockchain");
      }
    } catch (err: any) {
      console.error("Blockchain connectivity error:", err);
      setError(err);
      setStatus({
        isRunning: false,
        networkType: 'unknown',
        message: `Blockchain connection error: ${err.message || "Unknown error"}`,
        severity: 'error',
        timestamp: Date.now()
      });
      setNetworkInfo(null);
      return false;
    } finally {
      setIsLoading(false);
    }
  };

  // Toggle local database only mode
  const toggleLocalDatabaseOnly = (value: boolean) => {
    console.log(`Setting local database only mode: ${value}`);
    setLocalDatabaseOnly(value);
    
    if (!value) {
      // If turning off local DB mode, try connecting to blockchain
      checkConnection();
    }
  };

  useEffect(() => {
    checkConnection();

    // Set up periodic polling for blockchain status
    const POLLING_INTERVAL = parseInt(process.env.NEXT_PUBLIC_NETWORK_POLLING_INTERVAL || '60000');
    const intervalId = setInterval(() => {
      if (!localDatabaseOnly) {
        checkConnection();
      }
    }, POLLING_INTERVAL);
    
    return () => clearInterval(intervalId);
  }, [localDatabaseOnly]);

  // Return a properly shaped object that matches what the components expect
  return { 
    isConnected: status.isRunning, 
    isLoading, 
    error: error?.message || null,
    localDatabaseOnly,
    networkInfo,
    lastChecked: status.timestamp || 0,
    checkConnection,
    toggleLocalDatabaseOnly
  };
};

export default useBlockchainStatus;