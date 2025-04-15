"use client";

import { useCallback, useEffect, useState } from "react";
import { useAccount } from "wagmi";
import { NFTListing } from "~~/types/marketplace";
import { nftListingsService } from "~~/services/nft-listings-service";
import { notification } from "~~/utils/scaffold-eth";
import { useBlockchainStatus } from "~~/hooks/useBlockchainStatus";

export const useSeaport = () => {
  const [listings, setListings] = useState<NFTListing[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [error, setError] = useState<Error | null>(null);
  const { address: connectedAddress } = useAccount();
  const { isConnected, localDatabaseOnly } = useBlockchainStatus();

  // Load all listings
  const loadListings = useCallback(async () => {
    try {
      setIsLoading(true);
      setError(null);
      
      const fetchedListings = await nftListingsService.getAllListings();
      setListings(fetchedListings);
      
      // Removed the blockchain connection warning toast for local networks
      // Local networks will now silently use the local database without showing the warning
    } catch (err) {
      console.error("Error loading NFT listings:", err);
      setError(err instanceof Error ? err : new Error("Failed to load listings"));
      
      // Keep this error notification as it's for actual errors, not just connection state
      notification.error("Failed to load NFT listings. Please try again.");
    } finally {
      setIsLoading(false);
    }
  }, [isConnected, localDatabaseOnly]);

  // Get listings - separated function to allow selective refetching
  const getListings = useCallback(async () => {
    try {
      setIsLoading(true);
      setError(null);
      const fetchedListings = await nftListingsService.getAllListings();
      setListings(fetchedListings);
      return fetchedListings;
    } catch (err) {
      console.error("Error fetching NFT listings:", err);
      setError(err instanceof Error ? err : new Error("Failed to fetch listings"));
      throw err;
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Create a new listing
  const createListing = useCallback(async (listingData: Omit<NFTListing, "id" | "seller" | "createdAt" | "updatedAt">) => {
    if (!connectedAddress) {
      notification.error("Please connect your wallet to create a listing");
      throw new Error("Wallet not connected");
    }

    try {
      setIsLoading(true);
      setError(null);
      
      const newListing = await nftListingsService.createListing({
        ...listingData,
        seller: connectedAddress,
      });
      
      // Update the listings state with the new listing
      setListings(currentListings => [newListing, ...currentListings]);
      
      notification.success("NFT listed successfully!");
      return newListing;
    } catch (err) {
      console.error("Error creating NFT listing:", err);
      setError(err instanceof Error ? err : new Error("Failed to create listing"));
      notification.error("Failed to create listing. Please try again.");
      throw err;
    } finally {
      setIsLoading(false);
    }
  }, [connectedAddress]);

  // Buy an NFT
  const buyNFT = useCallback(async (listingId: string) => {
    // If we're in local database only mode, don't require a connected address
    // Otherwise, require a connected wallet
    if (!localDatabaseOnly && !connectedAddress) {
      notification.error("Please connect your wallet to buy an NFT");
      throw new Error("Wallet not connected");
    }

    try {
      setIsLoading(true);
      setError(null);
      
      // In a real implementation, this would interact with Seaport
      // For now, we'll just simulate a successful purchase
      const listing = listings.find(l => l.id === listingId);
      
      if (!listing) {
        throw new Error("Listing not found");
      }
      
      // Check if listing is offchain buyable when in local database only mode
      if (localDatabaseOnly && !listing.offchainBuyable) {
        notification.error("This NFT requires blockchain connection to purchase");
        throw new Error("Blockchain connection required for this listing");
      }
      
      // Simulate purchase success
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Remove the listing from state and database
      await nftListingsService.deleteListing(listingId);
      setListings(currentListings => currentListings.filter(l => l.id !== listingId));
      
      notification.success("NFT purchased successfully!");
      return true;
    } catch (err) {
      console.error("Error purchasing NFT:", err);
      setError(err instanceof Error ? err : new Error("Failed to purchase NFT"));
      notification.error("Failed to purchase NFT. Please try again.");
      throw err;
    } finally {
      setIsLoading(false);
    }
  }, [connectedAddress, listings, localDatabaseOnly]);

  // Reset blockchain data if needed
  const resetBlockchainData = useCallback(async () => {
    try {
      setIsLoading(true);
      setError(null);
      
      const success = await nftListingsService.resetBlockchainData();
      if (success) {
        notification.success("Blockchain data reset successfully!");
        await loadListings(); // Reload listings after reset
      } else {
        notification.error("Failed to reset blockchain data");
      }
      
      return success;
    } catch (err) {
      console.error("Error resetting blockchain data:", err);
      setError(err instanceof Error ? err : new Error("Failed to reset blockchain data"));
      notification.error("Failed to reset blockchain data. Please try again.");
      return false;
    } finally {
      setIsLoading(false);
    }
  }, [loadListings]);

  // Load listings on initial render
  useEffect(() => {
    loadListings();
  }, [loadListings]);

  return {
    listings,
    isLoading,
    error,
    getListings,
    createListing,
    buyNFT,
    loadListings,
    resetBlockchainData
  };
};
