"use client";

import { BlockchainDebug } from "../../../components/blockchain/BlockchainDebug";
import { useEffect } from "react";
import { checkBlockchainConnection } from "../../../utils/blockchain-diagnostic";

export default function BlockchainDebugPage() {
  useEffect(() => {
    // Run a quick check at page load
    const checkConnection = async () => {
      const isConnected = await checkBlockchainConnection();
      console.log("Initial blockchain connection check:", isConnected ? "Connected" : "Disconnected");
    };
    
    checkConnection();
  }, []);

  return (
    <div className="container mx-auto px-4 py-8">
      <h1 className="text-3xl font-bold mb-6">Blockchain Connection Debug</h1>
      
      <div className="mb-8">
        <p className="mb-4">
          This page helps diagnose issues with your local blockchain connection.
          Use the tools below to check if your blockchain is running properly 
          and if the UI can connect to it.
        </p>
        
        <div className="alert alert-info mb-4">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" className="stroke-current shrink-0 w-6 h-6"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
          <div>
            <h3 className="font-bold">Quick Tips</h3>
            <div className="text-sm mt-2">
              <ol className="list-decimal list-inside">
                <li>Make sure your blockchain is running at <code className="bg-base-300 px-1 rounded">http://localhost:8545</code></li>
                <li>Check if your <code className="bg-base-300 px-1 rounded">start-blockchain-network.sh</code> script is running correctly</li>
                <li>Check browser console for any errors</li>
                <li>Try toggling between blockchain and local database mode</li>
              </ol>
            </div>
          </div>
        </div>
      </div>
      
      <BlockchainDebug />
      
      <div className="mt-8">
        <h2 className="text-2xl font-bold mb-4">Manual Connection Commands</h2>
        <div className="bg-base-300 p-4 rounded-lg">
          <p className="mb-4">If you're having trouble with the connection, try these commands in your terminal:</p>
          
          <div className="overflow-x-auto">
            <pre className="p-4 bg-base-100 rounded">
              {`# Check if blockchain is running
lsof -i :8545

# Restart the blockchain service
./scripts/start-blockchain-network.sh

# Check blockchain logs
cat ./scripts/logs/blockchain.log

# Test JSON-RPC connection manually
curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545
`}
            </pre>
          </div>
        </div>
      </div>
    </div>
  );
}