import * as fs from 'fs';
import * as path from 'path';
import { getImageUrl } from './storage-service';

export interface NFTListing {
  id: string;
  name: string;
  description: string;
  imageUrl: string;
  price: number;
  tokenId: string;
  tokenAddress: string;
  tokenType: string;
  amount: number;
  createdAt: string;
  updatedAt: string;
  owner?: string;
  offchainBuyable?: boolean;
}

// Storage key for local storage
const LISTINGS_STORAGE_KEY = 'nft-listings-data';

// Path to JSON file storing NFT listings for server-side
const LISTINGS_FILE_PATH = typeof process !== 'undefined' ? path.join(process.cwd(), 'data', 'nft-listings.json') : '';

// Default NFT listings to use when storage is empty
const DEFAULT_NFT_LISTINGS: NFTListing[] = [
  {
    id: '1',
    name: 'Cosmic Explorer #001',
    description: 'A rare digital space explorer NFT from the Cosmic Collection. This unique digital collectible features a blend of sci-fi aesthetics and digital art innovation.',
    imageUrl: 'https://picsum.photos/seed/nft1/500/500',
    price: 0.15,
    tokenId: '1',
    tokenAddress: '0x8a90cab2b38dba80c64b7734e58ee1db38b8992e',
    tokenType: 'ERC721',
    amount: 1,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    owner: '0x0000000000000000000000000000000000000000',
    offchainBuyable: true
  },
  {
    id: '2',
    name: 'Digital Landscape #42',
    description: 'Beautiful abstract digital landscape from the Nature Series. Created by renowned digital artist Maya Johnson, this piece captures the essence of natural beauty in digital form.',
    imageUrl: 'https://picsum.photos/seed/nft2/500/500',
    price: 0.25,
    tokenId: '42',
    tokenAddress: '0x8a90cab2b38dba80c64b7734e58ee1db38b8992e',
    tokenType: 'ERC721',
    amount: 1,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    owner: '0x0000000000000000000000000000000000000000',
    offchainBuyable: true
  },
  {
    id: '3',
    name: 'Crypto Punk Tribute #88',
    description: 'A tribute to the iconic CryptoPunks collection. This NFT pays homage to the original blockchain collectibles that started the NFT revolution.',
    imageUrl: 'https://picsum.photos/seed/nft3/500/500',
    price: 0.35,
    tokenId: '88',
    tokenAddress: '0x8a90cab2b38dba80c64b7734e58ee1db38b8992e',
    tokenType: 'ERC721',
    amount: 1,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    owner: '0x0000000000000000000000000000000000000000',
    offchainBuyable: true
  },
  {
    id: '4',
    name: 'Meta Cube Collection #7',
    description: 'Part of the exclusive Meta Cube Collection. This digital asset represents ownership of a unique virtual object in the expanding metaverse.',
    imageUrl: 'https://picsum.photos/seed/nft4/500/500',
    price: 0.12,
    tokenId: '7',
    tokenAddress: '0xed5af388653567af2f388e6224dc7c4b3241c544',
    tokenType: 'ERC721',
    amount: 1,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    owner: '0x0000000000000000000000000000000000000000',
    offchainBuyable: true
  },
  {
    id: '5',
    name: 'Quantum Pixel #256',
    description: 'A generative art piece created through quantum computing algorithms. Each pixel placement represents a quantum state calculation, making this a true blend of art and science.',
    imageUrl: 'https://picsum.photos/seed/nft5/500/500',
    price: 0.5,
    tokenId: '256',
    tokenAddress: '0xed5af388653567af2f388e6224dc7c4b3241c544',
    tokenType: 'ERC721',
    amount: 1,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    owner: '0x0000000000000000000000000000000000000000',
    offchainBuyable: true
  }
];

// Check if we're in a browser environment
const isBrowser = typeof window !== 'undefined';
const useLocalStorage = isBrowser && process.env.NEXT_PUBLIC_USE_LOCAL_STORAGE === 'true';

// Ensure data directory exists (server-side only)
const ensureDataDirectory = () => {
  if (!useLocalStorage && !isBrowser) {
    const dataDir = path.join(process.cwd(), 'data');
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }
    
    // Create listings file if it doesn't exist
    if (!fs.existsSync(LISTINGS_FILE_PATH)) {
      fs.writeFileSync(LISTINGS_FILE_PATH, JSON.stringify([], null, 2));
    }
  }
};

// Load listings from storage (either file system or localStorage)
const loadListingsFromDB = (): NFTListing[] => {
  try {
    let loadedListings: NFTListing[] = [];
    
    if (useLocalStorage) {
      // Browser environment - use localStorage
      const data = localStorage.getItem(LISTINGS_STORAGE_KEY);
      loadedListings = data ? JSON.parse(data) : [];
    } else if (!isBrowser) {
      // Server environment - use file system
      ensureDataDirectory();
      const data = fs.readFileSync(LISTINGS_FILE_PATH, 'utf-8');
      loadedListings = JSON.parse(data);
    }
    
    // If no listings found, return default ones
    if (!loadedListings || loadedListings.length === 0) {
      console.log('No listings found, using default NFT listings');
      
      // Also save the default listings to storage for next time
      saveListingsToDB(DEFAULT_NFT_LISTINGS);
      return DEFAULT_NFT_LISTINGS;
    }
    
    return loadedListings;
  } catch (error) {
    console.error("Error loading listings:", error);
    console.log('Using default NFT listings after error');
    
    // On error, return default listings
    return DEFAULT_NFT_LISTINGS;
  }
};

// Save listings to storage (either file system or localStorage)
const saveListingsToDB = (listings: NFTListing[]) => {
  try {
    if (useLocalStorage) {
      // Browser environment - use localStorage
      localStorage.setItem(LISTINGS_STORAGE_KEY, JSON.stringify(listings));
    } else if (!isBrowser) {
      // Server environment - use file system
      ensureDataDirectory();
      fs.writeFileSync(LISTINGS_FILE_PATH, JSON.stringify(listings, null, 2));
    }
  } catch (error) {
    console.error("Error saving listings:", error);
  }
};

// Service to manage NFT listings
export const nftListingsService = {
  // Get all listings
  getAllListings: async (): Promise<NFTListing[]> => {
    const listings = loadListingsFromDB();
    
    // Process image URLs to ensure they're accessible
    return listings.map(listing => ({
      ...listing,
      imageUrl: getImageUrl(listing.imageUrl) // Convert URL if necessary
    }));
  },
  
  // Get listing by ID
  getListingById: async (id: string): Promise<NFTListing | null> => {
    const listings = loadListingsFromDB();
    const listing = listings.find(l => l.id === id);
    
    if (!listing) return null;
    
    // Process image URL
    return {
      ...listing,
      imageUrl: getImageUrl(listing.imageUrl)
    };
  },
  
  // Create new listing
  createListing: async (listingData: Omit<NFTListing, 'id' | 'createdAt' | 'updatedAt'>): Promise<NFTListing> => {
    try {
      // Create new listing with random ID
      const now = new Date().toISOString();
      const newListing: NFTListing = {
        ...listingData,
        id: `${Date.now()}`, // Create ID based on timestamp
        createdAt: now,
        updatedAt: now
      };
      
      console.log("Creating new listing:", newListing);
      
      // Add to database
      const existingListings = loadListingsFromDB();
      const updatedListings = [newListing, ...existingListings];
      saveListingsToDB(updatedListings);
      
      return {
        ...newListing,
        imageUrl: getImageUrl(newListing.imageUrl)
      };
    } catch (error) {
      console.error("Error creating listing:", error);
      throw new Error("Failed to create new listing: " + error);
    }
  },
  
  // Update listing
  updateListing: async (id: string, updateData: Partial<NFTListing>): Promise<NFTListing | null> => {
    try {
      const listings = loadListingsFromDB();
      const index = listings.findIndex(l => l.id === id);
      
      if (index === -1) return null;
      
      const now = new Date().toISOString();
      const updatedListing: NFTListing = {
        ...listings[index],
        ...updateData,
        updatedAt: now
      };
      
      listings[index] = updatedListing;
      saveListingsToDB(listings);
      
      return {
        ...updatedListing,
        imageUrl: getImageUrl(updatedListing.imageUrl)
      };
    } catch (error) {
      console.error("Error updating listing:", error);
      throw new Error("Failed to update listing: " + error);
    }
  },
  
  // Delete listing
  deleteListing: async (id: string): Promise<boolean> => {
    try {
      const listings = loadListingsFromDB();
      const index = listings.findIndex(l => l.id === id);
      
      if (index === -1) return false;
      
      listings.splice(index, 1);
      saveListingsToDB(listings);
      
      return true;
    } catch (error) {
      console.error("Error deleting listing:", error);
      throw new Error("Failed to delete listing: " + error);
    }
  },
  
  // Get listings by wallet address
  getListingsByAddress: async (address: string): Promise<NFTListing[]> => {
    const listings = loadListingsFromDB();
    const filteredListings = listings.filter(l => l.owner === address);
    
    // Process image URLs
    return filteredListings.map(listing => ({
      ...listing,
      imageUrl: getImageUrl(listing.imageUrl)
    }));
  },
  
  // Reset blockchain data
  resetBlockchainData: async (): Promise<boolean> => {
    try {
      saveListingsToDB([]);
      return true;
    } catch (error) {
      console.error("Error resetting blockchain data:", error);
      return false;
    }
  }
};