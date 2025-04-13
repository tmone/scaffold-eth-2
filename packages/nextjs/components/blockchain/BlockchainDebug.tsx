"use client";

import { useEffect, useState } from "react";
import { BlockchainDiagnostic } from "../../utils/blockchain-diagnostic";
import useBlockchainStatus from "../../hooks/useBlockchainStatus";

export const BlockchainDebug: React.FC = () => {
  const blockchainStatus = useBlockchainStatus();
  const [diagnosticResult, setDiagnosticResult] = useState<any>(null);
  const [isRunningDiagnostic, setIsRunningDiagnostic] = useState(false);
  const [customRpcUrl, setCustomRpcUrl] = useState("http://localhost:8545");

  const runDiagnostic = async () => {
    setIsRunningDiagnostic(true);
    try {
      const diagnostic = new BlockchainDiagnostic(customRpcUrl);
      const result = await diagnostic.runDiagnostic();
      setDiagnosticResult(result);
    } catch (error) {
      console.error("Diagnostic error:", error);
      setDiagnosticResult({ success: false, error: String(error) });
    } finally {
      setIsRunningDiagnostic(false);
    }
  };

  useEffect(() => {
    // Run diagnostic once on mount
    runDiagnostic();
  }, []);

  return (
    <div className="bg-base-200 p-4 rounded-lg shadow-md mb-6">
      <h2 className="text-xl font-bold mb-3">Blockchain Connection Debugger</h2>
      
      {/* Status from hook */}
      <div className="mb-4">
        <h3 className="text-lg font-semibold">Hook Status</h3>
        <div className="grid grid-cols-2 gap-2 mb-2">
          <div>Connection:</div>
          <div className={blockchainStatus.isConnected ? "text-success" : "text-error"}>
            {blockchainStatus.isConnected ? "Connected" : "Disconnected"}
          </div>
          
          <div>Loading:</div>
          <div>{blockchainStatus.isLoading ? "Yes" : "No"}</div>
          
          <div>Local DB Only:</div>
          <div>{blockchainStatus.localDatabaseOnly ? "Yes" : "No"}</div>
          
          {blockchainStatus.networkInfo && (
            <>
              <div>Network:</div>
              <div>{blockchainStatus.networkInfo.name} (Chain ID: {blockchainStatus.networkInfo.chainId})</div>
              
              {blockchainStatus.networkInfo.blockNumber !== undefined && (
                <>
                  <div>Block:</div>
                  <div>{blockchainStatus.networkInfo.blockNumber}</div>
                </>
              )}
            </>
          )}
          
          {blockchainStatus.error && (
            <>
              <div>Error:</div>
              <div className="text-error">{blockchainStatus.error}</div>
            </>
          )}
          
          <div>Last Checked:</div>
          <div>{blockchainStatus.lastChecked ? new Date(blockchainStatus.lastChecked).toLocaleTimeString() : "Never"}</div>
        </div>
      </div>
      
      {/* Manual diagnostic */}
      <div className="mb-4">
        <div className="flex items-end gap-2 mb-2">
          <div className="form-control flex-grow">
            <label className="label">
              <span className="label-text">RPC URL</span>
            </label>
            <input
              type="text"
              className="input input-bordered w-full"
              value={customRpcUrl}
              onChange={(e) => setCustomRpcUrl(e.target.value)}
              placeholder="http://localhost:8545"
            />
          </div>
          <button 
            className="btn btn-primary" 
            onClick={runDiagnostic}
            disabled={isRunningDiagnostic}
          >
            {isRunningDiagnostic ? (
              <>
                <span className="loading loading-spinner loading-sm"></span>
                Running...
              </>
            ) : "Run Diagnostic"}
          </button>
        </div>

        {diagnosticResult && (
          <div className="mt-4 p-3 bg-base-300 rounded">
            <h4 className="font-semibold mb-2">Diagnostic Results:</h4>
            <div className={`mb-2 ${diagnosticResult.success ? "text-success" : "text-error"}`}>
              Status: {diagnosticResult.success ? "Success" : "Failed"}
            </div>
            
            {diagnosticResult.details && (
              <div className="grid grid-cols-2 gap-2">
                <div>Connected:</div>
                <div>{diagnosticResult.details.connected ? "Yes" : "No"}</div>
                
                <div>Latency:</div>
                <div>{diagnosticResult.details.latency}ms</div>
                
                {diagnosticResult.details.networkInfo && (
                  <>
                    <div>Network:</div>
                    <div>
                      {diagnosticResult.details.networkInfo.name} 
                      (Chain ID: {diagnosticResult.details.networkInfo.chainId})
                    </div>
                  </>
                )}
                
                {diagnosticResult.details.blockNumber !== undefined && (
                  <>
                    <div>Block Number:</div>
                    <div>{diagnosticResult.details.blockNumber}</div>
                  </>
                )}
                
                {diagnosticResult.details.accounts && (
                  <>
                    <div>Accounts:</div>
                    <div>{diagnosticResult.details.accounts.length}</div>
                  </>
                )}
                
                {diagnosticResult.details.gasPrice && (
                  <>
                    <div>Gas Price:</div>
                    <div>{diagnosticResult.details.gasPrice}</div>
                  </>
                )}
              </div>
            )}
            
            {diagnosticResult.error && (
              <div className="text-error mt-2">
                Error: {diagnosticResult.error}
              </div>
            )}
          </div>
        )}
      </div>
      
      {/* Actions */}
      <div className="flex gap-2">
        <button
          className="btn btn-sm btn-primary"
          onClick={() => blockchainStatus.checkConnection()}
          disabled={blockchainStatus.isLoading}
        >
          {blockchainStatus.isLoading ? (
            <>
              <span className="loading loading-spinner loading-xs"></span>
              Checking...
            </>
          ) : "Check Connection"}
        </button>
        
        <button
          className="btn btn-sm btn-secondary"
          onClick={() => blockchainStatus.toggleLocalDatabaseOnly(!blockchainStatus.localDatabaseOnly)}
        >
          {blockchainStatus.localDatabaseOnly ? "Use Blockchain" : "Use Local DB"}
        </button>
      </div>
    </div>
  );
};

export default BlockchainDebug;