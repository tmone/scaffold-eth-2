'use client';

/**
 * This component initializes the environment variables in the browser
 * by injecting them into the window object.
 */
export default function EnvInitializer() {
  // Only run in the browser
  if (typeof window !== "undefined") {
    // Create a container for environment variables
    (window as any).__ENV__ = {
      NEXT_PUBLIC_DISABLE_ENS: process.env.NEXT_PUBLIC_DISABLE_ENS,
      NEXT_PUBLIC_LOCAL_RPC_URL: process.env.NEXT_PUBLIC_LOCAL_RPC_URL,
      NEXT_PUBLIC_NETWORK_POLLING_INTERVAL: process.env.NEXT_PUBLIC_NETWORK_POLLING_INTERVAL,
      NEXT_PUBLIC_RPC_POLLING_INTERVAL: process.env.NEXT_PUBLIC_RPC_POLLING_INTERVAL,
      NEXT_PUBLIC_USE_BURNER_WALLET: process.env.NEXT_PUBLIC_USE_BURNER_WALLET,
    };
  }
  
  return null; // This component doesn't render anything
}