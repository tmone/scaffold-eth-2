"use client";

import { useEffect, useState } from "react";
import { ethers } from "ethers";

interface BlockchainStatus {
  isConnected: boolean;
  isLoading: boolean;
  error: string | null;
  lastChecked: number;
  localDatabaseOnly: boolean;
  networkInfo?: {
    name: string;
    chainId: number;
    blockNumber?: number;
  };
}

// Add configuration options to make the hook more flexible
interface BlockchainStatusConfig {
  rpcUrl?: string;
  maxRetries?: number;
  retryDelay?: number;
  connectionTimeout?: number;
  checkInterval?: number;
  useLocalDatabaseOnly?: boolean;
}

const DEFAULT_CONFIG: BlockchainStatusConfig = {
  rpcUrl: "http://localhost:8545",
  maxRetries: 5, // Increased from 3 to 5
  retryDelay: 2000, // Increased from 1s to 2s
  connectionTimeout: 8000, // Increased from 5s to 8s
  checkInterval: 30000, // Keep the 30s interval
  useLocalDatabaseOnly: false
};

export const useBlockchainStatus = (config?: BlockchainStatusConfig) => {
  const effectiveConfig = { ...DEFAULT_CONFIG, ...config };
  
  const [status, setStatus] = useState<BlockchainStatus>({
    isConnected: false,
    isLoading: !effectiveConfig.useLocalDatabaseOnly,
    error: null,
    lastChecked: 0,
    localDatabaseOnly: Boolean(effectiveConfig.useLocalDatabaseOnly)
  });

  const checkConnection = async () => {
    // If we're in local database only mode, skip connection attempts
    if (status.localDatabaseOnly) {
      setStatus({
        isConnected: false,
        isLoading: false,
        error: null,
        lastChecked: Date.now(),
        localDatabaseOnly: true
      });
      return false;
    }

    try {
      setStatus(prev => ({ ...prev, isLoading: true, error: null }));

      let retries = 0;
      const maxRetries = effectiveConfig.maxRetries || DEFAULT_CONFIG.maxRetries!;
      const retryDelay = effectiveConfig.retryDelay || DEFAULT_CONFIG.retryDelay!;
      const connectionTimeout = effectiveConfig.connectionTimeout || DEFAULT_CONFIG.connectionTimeout!;
      
      while (retries < maxRetries) {
        try {
          // Connect to the local blockchain network with provided URL
          const provider = new ethers.providers.JsonRpcProvider(
            effectiveConfig.rpcUrl || DEFAULT_CONFIG.rpcUrl
          );
          
          // Set a timeout for the request
          const networkPromise = provider.getNetwork();
          const timeoutPromise = new Promise((_, reject) => {
            setTimeout(() => reject(new Error(`Network request timeout after ${connectionTimeout/1000} seconds`)), 
              connectionTimeout);
          });
          
          // Race the network request against the timeout
          const network = await Promise.race([networkPromise, timeoutPromise]) as ethers.providers.Network;
          console.log(`Connected to network: ${network.name} (chainId: ${network.chainId})`);
          
          // Then try a simple request to ensure the node is fully responsive
          const blockNumber = await provider.getBlockNumber();
          console.log(`Current block number: ${blockNumber}`);
          
          // If we get here, we're connected - include network info in status
          setStatus({
            isConnected: true,
            isLoading: false,
            error: null,
            lastChecked: Date.now(),
            localDatabaseOnly: false,
            networkInfo: {
              name: network.name,
              chainId: network.chainId,
              blockNumber
            }
          });
          
          return true;
        } catch (error) {
          retries++;
          console.error(`Blockchain connection attempt ${retries}/${maxRetries} failed:`, error);
          
          if (retries < maxRetries) {
            console.log(`Retrying in ${retryDelay/1000} seconds...`);
            await new Promise(resolve => setTimeout(resolve, retryDelay));
          }
        }
      }
      
      // If we get here, all attempts failed
      throw new Error(`Failed to connect after ${maxRetries} attempts`);
    } catch (error) {
      console.error("Blockchain connection check failed:", error);
      setStatus({
        isConnected: false,
        isLoading: false,
        error: "Cannot connect to blockchain network. Please check your network connection and blockchain status.",
        lastChecked: Date.now(),
        localDatabaseOnly: false
      });
      
      return false;
    }
  };

  // Toggle between local database mode and blockchain mode
  const toggleLocalDatabaseOnly = (value: boolean) => {
    console.log(`Toggling local database only mode: ${value}`);
    setStatus(prev => ({
      ...prev,
      localDatabaseOnly: value,
      isLoading: !value && !prev.isConnected,
      error: value ? null : prev.error
    }));
    
    if (!value) {
      // If switching to blockchain mode, try to connect
      checkConnection();
    }
  };

  // Check connection when component mounts
  useEffect(() => {
    // Only check connection if not in local database only mode
    if (!status.localDatabaseOnly) {
      checkConnection();

      // Check connection periodically
      const intervalId = setInterval(() => {
        if (!status.localDatabaseOnly) {
          checkConnection();
        }
      }, effectiveConfig.checkInterval || DEFAULT_CONFIG.checkInterval);

      return () => clearInterval(intervalId);
    }
  }, [status.localDatabaseOnly]);

  return {
    ...status,
    checkConnection,
    toggleLocalDatabaseOnly
  };
};

export default useBlockchainStatus;