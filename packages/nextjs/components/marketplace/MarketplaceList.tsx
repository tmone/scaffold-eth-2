"use client";

import { useCallback, useEffect, useState } from "react";
import { Address } from "~~/components/scaffold-eth";
import { useSeaport } from "~~/hooks/useSeaport";
import { useBlockchainStatus } from "~~/hooks/useBlockchainStatus";
import { notification } from "~~/utils/scaffold-eth";

export const MarketplaceList = () => {
  const { listings, isLoading, error, buyNFT, loadListings, resetBlockchainData } = useSeaport();
  const [isPurchasing, setIsPurchasing] = useState<string | null>(null);
  const [refreshInterval, setRefreshInterval] = useState<NodeJS.Timeout | null>(null);
  // Use local database only mode (true) to skip blockchain connection attempts
  const { isConnected, isLoading: isBlockchainLoading, localDatabaseOnly } = useBlockchainStatus(true);
  const [isResetting, setIsResetting] = useState(false);

  const handleBuyNFT = async (listingId: string) => {
    try {
      setIsPurchasing(listingId);
      await buyNFT(listingId);
    } catch (error) {
      console.error("Error purchasing NFT:", error);
    } finally {
      setIsPurchasing(null);
    }
  };

  // Function to refresh listings data
  const refreshListings = useCallback(async () => {
    try {
      await loadListings();
      console.log("NFT listings refreshed");
    } catch (error) {
      console.error("Error refreshing listings:", error);
    }
  }, [loadListings]);
  
  // Function to reset blockchain data and recreate NFTs if needed
  const handleResetData = async () => {
    try {
      setIsResetting(true);
      const success = await resetBlockchainData();
      if (success) {
        notification.success("Blockchain data and NFT listings have been reset successfully!");
        await refreshListings();
      }
    } catch (error) {
      console.error("Error resetting blockchain data:", error);
      notification.error("Failed to reset blockchain data. Please try again.");
    } finally {
      setIsResetting(false);
    }
  };

  // Set up a manual refresh every 10 seconds to catch any new tokens
  useEffect(() => {
    // Load listings immediately when component mounts
    refreshListings();

    // Set up refresh interval
    const interval = setInterval(refreshListings, 10000);
    setRefreshInterval(interval);

    // Clean up interval on component unmount
    return () => {
      if (refreshInterval) {
        clearInterval(refreshInterval);
      }
    };
  }, [refreshListings]);

  // Add a visibility change listener to refresh data when user returns to the page
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (document.visibilityState === 'visible') {
        refreshListings();
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);

    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
    };
  }, [refreshListings]);

  return (
    <div className="w-full">
      <div className="flex justify-between items-center mb-4">
        <h2 className="text-2xl font-bold">Available NFTs</h2>
        <div className="flex gap-2 items-center">
          {!isConnected && (
            <div className="text-sm text-warning flex items-center gap-1">
              <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
              <span>No blockchain connection. Using local data only.</span>
            </div>
          )}
          <div className="flex gap-2">
            <button 
              onClick={handleResetData} 
              className="btn btn-sm btn-warning"
              disabled={isLoading || isResetting}
              title="Reset all blockchain data and NFT listings"
            >
              {isResetting ? (
                <span className="loading loading-spinner loading-xs"></span>
              ) : (
                'Reset NFT Data'
              )}
            </button>
            <button 
              onClick={refreshListings} 
              className="btn btn-sm btn-outline"
              disabled={isLoading}
            >
              {isLoading ? (
                <span className="loading loading-spinner loading-xs"></span>
              ) : (
                'Refresh'
              )}
            </button>
          </div>
        </div>
      </div>
      
      {!isConnected && (
        <div className="alert alert-warning mb-4">
          <svg xmlns="http://www.w3.org/2000/svg" className="stroke-current shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
          </svg>
          <div>
            <h3 className="font-bold">No blockchain connection</h3>
            <div className="text-sm">Displaying NFTs from local database. Some features may be limited.</div>
          </div>
        </div>
      )}
      
      {error && (
        <div className="alert alert-error mb-4">
          <svg xmlns="http://www.w3.org/2000/svg" className="stroke-current shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <div>
            <h3 className="font-bold">Error loading NFTs</h3>
            <div className="text-sm">Failed to load NFT listings. Please try again later or reset NFT data.</div>
          </div>
        </div>
      )}
      
      {isLoading && listings.length === 0 ? (
        <div className="flex justify-center items-center h-40">
          <span className="loading loading-spinner loading-lg"></span>
        </div>
      ) : listings.length === 0 ? (
        <div className="text-center p-8 border rounded-lg bg-base-200">
          <p>No NFT listings available at the moment.</p>
          <button 
            onClick={handleResetData}
            className="btn btn-sm btn-primary mt-4"
            disabled={isResetting}
          >
            {isResetting ? (
              <span className="loading loading-spinner loading-xs"></span>
            ) : (
              'Create Default NFT Listings'
            )}
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {listings.map((listing) => (
            <div key={listing.id} className="card bg-base-100 shadow-xl">
              <figure className="px-5 pt-5">
                <img
                  src={listing.imageUrl}
                  alt={listing.name}
                  className="rounded-xl h-48 w-full object-cover"
                />
              </figure>
              <div className="card-body">
                <h2 className="card-title">{listing.name}</h2>
                <p className="text-sm opacity-70 line-clamp-2">{listing.description}</p>
                
                <div className="mt-2 flex flex-col gap-1">
                  <div className="flex justify-between items-center">
                    <span className="text-sm opacity-70">Price</span>
                    <span className="text-lg font-bold">{listing.price} ETH</span>
                  </div>
                  
                  <div className="flex justify-between items-center">
                    <span className="text-sm opacity-70">Seller</span>
                    <Address address={listing.seller} size="sm" />
                  </div>
                  
                  {listing.tokenType === 'ERC1155' && listing.amount && (
                    <div className="flex justify-between items-center">
                      <span className="text-sm opacity-70">Quantity</span>
                      <span>{listing.amount} available</span>
                    </div>
                  )}
                </div>
                
                <div className="card-actions justify-end mt-4">
                  <button
                    className="btn btn-primary btn-sm w-full"
                    onClick={() => handleBuyNFT(listing.id)}
                    disabled={isPurchasing === listing.id || (!isConnected && !listing.offchainBuyable)}
                  >
                    {isPurchasing === listing.id ? (
                      <span className="loading loading-spinner loading-xs"></span>
                    ) : !isConnected ? (
                      'Connect Blockchain to Buy'
                    ) : (
                      'Buy Now'
                    )}
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default MarketplaceList;
