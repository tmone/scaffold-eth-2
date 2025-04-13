// NFT listings service using local storage as database
import { NFTListing } from "../types/marketplace";
import { ethers } from "ethers";

// Database implementation using browser localStorage
const DB_KEY = 'opensea_qc_nft_listings';

// Database helper functions
const loadListingsFromDB = (): NFTListing[] => {
  if (typeof window !== 'undefined') {
    try {
      const stored = localStorage.getItem(DB_KEY);
      return stored ? JSON.parse(stored) : [];
    } catch (error) {
      console.error('Failed to load NFTs from database:', error);
      return [];
    }
  }
  return [];
};

const saveListingsToDB = (listings: NFTListing[]): void => {
  if (typeof window !== 'undefined') {
    try {
      localStorage.setItem(DB_KEY, JSON.stringify(listings));
    } catch (error) {
      console.error('Failed to save NFTs to database:', error);
    }
  }
};

// Create default NFT listings if none exist
const createDefaultListings = (): NFTListing[] => {
  const now = new Date().toISOString();
  const defaultListings: NFTListing[] = [
    {
      id: "default-1",
      name: "OpenSea QC NFT #1",
      description: "A default NFT created when no listings were found",
      imageUrl: "https://picsum.photos/seed/opensea1/400",
      price: 0.01,
      seller: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266", // Local hardhat address
      tokenId: "1",
      tokenAddress: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
      tokenType: "ERC721",
      createdAt: now,
      updatedAt: now
    }
  ];
  
  saveListingsToDB(defaultListings);
  return defaultListings;
};

// Simulate API delay for realistic behavior
const simulateApiDelay = () => new Promise(resolve => setTimeout(resolve, 500));

// Blockchain connection check function
const checkBlockchainConnection = async (): Promise<boolean> => {
  let retries = 0;
  const maxRetries = 3;
  const retryDelay = 1000; // 1 second delay between retries
  
  while (retries < maxRetries) {
    try {
      const provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
      
      // Use Promise.race to implement timeout instead of modifying the connection object
      const networkPromise = provider.getNetwork();
      const timeoutPromise = new Promise((_, reject) => {
        setTimeout(() => reject(new Error('Network request timeout after 5 seconds')), 5000);
      });
      
      // Race the network request against the timeout
      const network = await Promise.race([networkPromise, timeoutPromise]) as ethers.providers.Network;
      console.log(`Connected to network: ${network.name} (chainId: ${network.chainId})`);
      
      // Then try a simple request to ensure the node is fully responsive
      const blockNumber = await provider.getBlockNumber();
      console.log(`Current block number: ${blockNumber}`);
      
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
  
  console.error("All blockchain connection attempts failed");
  return false;
};

// Service main exports
export const nftListingsService = {
  // Get all listings
  getAllListings: async (): Promise<NFTListing[]> => {
    await simulateApiDelay();
    console.log("Fetching all listings from database");
    
    try {
      // Try to connect to blockchain but continue even if it fails
      const isConnected = await checkBlockchainConnection();
      if (!isConnected) {
        console.warn("Blockchain connection failed, proceeding with local database only");
      }
      
      // Load from database
      let listings = loadListingsFromDB();
      
      // If no listings in database, create default ones
      if (listings.length === 0) {
        console.log("No listings found in database, creating default listings");
        listings = createDefaultListings();
      }
      
      return [...listings];
    } catch (error) {
      console.error("Error fetching listings:", error);
      
      // Even if there's an error, try to return whatever is in the database
      const listings = loadListingsFromDB();
      if (listings.length > 0) {
        return [...listings];
      }
      
      // If everything fails, create and return default listings
      return createDefaultListings();
    }
  },

  // Get a single listing by ID
  getListing: async (id: string): Promise<NFTListing | undefined> => {
    await simulateApiDelay();
    
    try {
      // Try to connect to blockchain but continue even if it fails
      const isConnected = await checkBlockchainConnection();
      if (!isConnected) {
        console.warn("Blockchain connection failed, proceeding with local database only");
      }
      
      const listings = loadListingsFromDB();
      return listings.find(listing => listing.id === id);
    } catch (error) {
      console.error("Error fetching listing:", error);
      // Try to get from database even if blockchain connection fails
      const listings = loadListingsFromDB();
      return listings.find(listing => listing.id === id);
    }
  },

  // Create a new listing
  createListing: async (listingData: Omit<NFTListing, "id" | "createdAt" | "updatedAt">): Promise<NFTListing> => {
    await simulateApiDelay();
    
    try {
      // Try to connect to blockchain but continue even if it fails
      const isConnected = await checkBlockchainConnection();
      if (!isConnected) {
        console.warn("Blockchain connection failed, proceeding with local database only");
      }
      
      // Process image URL for IPFS compatibility
      let imageUrl = listingData.imageUrl;
      if (imageUrl && imageUrl.startsWith("ipfs://")) {
        imageUrl = `https://ipfs.example.com/${imageUrl.substring(7)}`;
      }
      
      // Create new listing
      const now = new Date().toISOString();
      const newListing: NFTListing = {
        ...listingData,
        imageUrl,
        id: `${Date.now()}`, // Create random ID based on timestamp
        createdAt: now,
        updatedAt: now
      };
      
      console.log("Creating new listing:", newListing);
      
      // Add to database
      const existingListings = loadListingsFromDB();
      const updatedListings = [newListing, ...existingListings];
      saveListingsToDB(updatedListings);
      
      return newListing;
    } catch (error) {
      console.error("Error creating listing:", error);
      throw new Error("Failed to create new listing: " + error);
    }
  },

  // Update an existing listing
  updateListing: async (id: string, listingData: Partial<NFTListing>): Promise<NFTListing | undefined> => {
    await simulateApiDelay();
    
    try {
      // Try to connect to blockchain but continue even if it fails
      const isConnected = await checkBlockchainConnection();
      if (!isConnected) {
        console.warn("Blockchain connection failed, proceeding with local database only");
      }
      
      // Update in database
      const listings = loadListingsFromDB();
      const index = listings.findIndex(listing => listing.id === id);
      if (index === -1) return undefined;
      
      const updatedListing = {
        ...listings[index],
        ...listingData,
        updatedAt: new Date().toISOString()
      };
      
      listings[index] = updatedListing;
      saveListingsToDB(listings);
      
      return updatedListing;
    } catch (error) {
      console.error("Error updating listing:", error);
      throw new Error("Failed to update listing: " + error);
    }
  },

  // Delete a listing
  deleteListing: async (id: string): Promise<boolean> => {
    await simulateApiDelay();
    
    try {
      // Try to connect to blockchain but continue even if it fails
      const isConnected = await checkBlockchainConnection();
      if (!isConnected) {
        console.warn("Blockchain connection failed, proceeding with local database only");
      }
      
      // Delete from database
      const listings = loadListingsFromDB();
      const initialLength = listings.length;
      const filteredListings = listings.filter(listing => listing.id !== id);
      
      if (filteredListings.length !== initialLength) {
        saveListingsToDB(filteredListings);
        return true;
      }
      
      return false;
    } catch (error) {
      console.error("Error deleting listing:", error);
      throw new Error("Failed to delete listing: " + error);
    }
  },
  
  // Clear all listings and blockchain data if needed
  resetBlockchainData: async (): Promise<boolean> => {
    await simulateApiDelay();
    
    try {
      console.log("Resetting blockchain data and NFT listings");
      
      // Clear listings from database
      saveListingsToDB([]);
      
      // Create fresh default listings
      const defaultListings = createDefaultListings();
      console.log("Created fresh default listings:", defaultListings);
      
      return true;
    } catch (error) {
      console.error("Error resetting blockchain data:", error);
      return false;
    }
  }
};