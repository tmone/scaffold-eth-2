"use client";

import React, { useEffect, useState } from "react";
import { useAccount, useBalance } from "wagmi";
import { parseEther } from "viem";

export const WalletFunder = () => {
  const { address, isConnected } = useAccount();
  const { data: balance } = useBalance({ address });
  
  const [isFunding, setIsFunding] = useState(false);
  const [fundingStatus, setFundingStatus] = useState<"idle" | "loading" | "success" | "error">("idle");
  const [errorMessage, setErrorMessage] = useState("");

  // Check if the wallet needs funding (balance less than 1 ETH)
  const needsFunding = balance?.value && balance.value < parseEther("1");
  
  const fundWallet = async () => {
    if (!address || !isConnected) return;
    
    setIsFunding(true);
    setFundingStatus("loading");
    
    try {
      const response = await fetch("/api/fund-wallet", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ walletAddress: address }),
      });
      
      const data = await response.json();
      
      if (!response.ok || !data.success) {
        throw new Error(data.error || "Failed to fund wallet");
      }
      
      setFundingStatus("success");
      // Wait 2 seconds before resetting the UI
      setTimeout(() => {
        setIsFunding(false);
        setFundingStatus("idle");
      }, 2000);
    } catch (error: any) {
      console.error("Error funding wallet:", error);
      setFundingStatus("error");
      setErrorMessage(error.message || "An error occurred");
      // Reset after 5 seconds on error
      setTimeout(() => {
        setIsFunding(false);
        setFundingStatus("idle");
        setErrorMessage("");
      }, 5000);
    }
  };
  
  // Automatically show the funding button if the wallet is connected and has low balance
  if (!isConnected || !needsFunding) {
    return null;
  }
  
  return (
    <div className="fixed bottom-4 right-4 z-50 p-4 rounded-lg bg-base-100 shadow-lg border border-base-300">
      <div className="flex flex-col items-start gap-2">
        <div className="text-sm font-medium">
          Your wallet has low balance: {balance ? `${Number(balance?.formatted).toFixed(4)} ETH` : "Loading..."}
        </div>
        <button
          className={`btn btn-primary btn-sm ${fundingStatus === "loading" ? "loading" : ""}`}
          onClick={fundWallet}
          disabled={isFunding}
        >
          {fundingStatus === "success" ? "✅ Wallet Funded!" : fundingStatus === "error" ? "❌ Failed" : "Fund Wallet with 100 ETH"}
        </button>
        {fundingStatus === "error" && <div className="text-error text-xs">{errorMessage}</div>}
      </div>
    </div>
  );
};

export default WalletFunder;