/**
 * Configuration utility for environment variables
 * 
 * Next.js automatically inlines process.env.NEXT_PUBLIC_* variables at build time
 * for client-side code, so we can safely use them here without the "process is not defined" error
 */

/**
 * Safely get boolean environment variable
 */
export const getEnvBoolean = (key: string, defaultValue: boolean = false): boolean => {
  // For Next.js, simply access the NEXT_PUBLIC_ variables directly
  // These are replaced at build time and are safe to use in client code
  const value = key.startsWith('NEXT_PUBLIC_') ? 
    (process.env as any)[key] : 
    undefined;
    
  if (value === undefined || value === "") return defaultValue;
  return value === "true" || value === "1";
};

/**
 * Main configuration object with default values
 * All values are properly inlined at build time by Next.js
 */
export const config = {
  ensResolution: {
    // Access environment variable directly to allow Next.js to inline it
    disabled: process.env.NEXT_PUBLIC_DISABLE_ENS === "true" || false
  },
  network: {
    localRpcUrl: process.env.NEXT_PUBLIC_LOCAL_RPC_URL || "http://localhost:8545",
    pollingInterval: parseInt(process.env.NEXT_PUBLIC_NETWORK_POLLING_INTERVAL || "30000"),
    rpcPollingInterval: parseInt(process.env.NEXT_PUBLIC_RPC_POLLING_INTERVAL || "30000"),
  },
  wallet: {
    useBurner: process.env.NEXT_PUBLIC_USE_BURNER_WALLET === "true" || true
  }
};