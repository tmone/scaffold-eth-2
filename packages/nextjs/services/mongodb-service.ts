// MongoDB service for NFT listings - SERVER SIDE ONLY
// This file should NEVER be imported directly from client components
// Use the nft-listings-service.ts for client-side code
import { MongoClient, ObjectId } from 'mongodb';

// Interface for NFT listings
export interface NFTListing {
  _id?: string | ObjectId; // MongoDB ID
  id: string;  // NFT listing ID (for compatibility)
  name: string;
  image: string;
  price: string;
  collection: string;
  tokenId: string;
  tokenAddress: string;
  createdAt?: number;
}

// MongoDB connection URL
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017';
const DB_NAME = process.env.MONGODB_DB_NAME || 'opensea_qc';
const COLLECTION_NAME = process.env.MONGODB_COLLECTION_NAME || 'nft_listings';

// Server-side check to prevent client-side usage
if (typeof window !== 'undefined') {
  throw new Error(
    'MongoDB service cannot be used on the client side. ' +
    'Use the nft-listings-service for client components instead.'
  );
}

class MongoDBService {
  private client: MongoClient | null = null;
  private connected = false;

  // Connect to MongoDB
  async connect(): Promise<void> {
    if (this.connected) return;
    
    try {
      this.client = new MongoClient(MONGODB_URI);
      await this.client.connect();
      this.connected = true;
      console.log('Connected to MongoDB successfully');
    } catch (error) {
      console.error('Failed to connect to MongoDB:', error);
      throw error;
    }
  }

  // Get database instance
  private async getDb() {
    if (!this.connected || !this.client) {
      await this.connect();
    }
    return this.client!.db(DB_NAME);
  }

  // Get collection
  private async getCollection() {
    const db = await this.getDb();
    return db.collection<NFTListing>(COLLECTION_NAME);
  }

  // Generate random NFT data
  private generateRandomNFTs(count: number): NFTListing[] {
    const listings: NFTListing[] = [];
    const adjectives = ["Rare", "Epic", "Legendary", "Cosmic", "Mystic", "Digital", "Quantum", "Pixel", "Neon", "Cyber"];
    const nouns = ["Artifact", "Token", "Gem", "Crystal", "Relic", "Collectible", "Treasure", "Asset", "Masterpiece", "Creation"];
    
    for (let i = 0; i < count; i++) {
      const id = `default-${Date.now()}-${i}`;
      const tokenId = Math.floor(Math.random() * 10000).toString();
      const name = `${adjectives[Math.floor(Math.random() * adjectives.length)]} ${nouns[Math.floor(Math.random() * nouns.length)]} #${tokenId}`;
      
      listings.push({
        id,
        name,
        image: `https://picsum.photos/seed/${id}/300/300`,
        price: (0.01 + Math.random() * 0.5).toFixed(3),
        collection: "OpenSea QC Collection",
        tokenId,
        tokenAddress: "0x5FbDB2315678afecb367f032d93F642f64180aa3", // Local contract address
        createdAt: Date.now() - Math.floor(Math.random() * 10000000)
      });
    }
    
    return listings;
  }

  // Initialize database with sample data if empty
  async initialize(): Promise<void> {
    try {
      await this.connect();
      const collection = await this.getCollection();
      
      // Check if collection is empty
      const count = await collection.countDocuments();
      
      if (count === 0) {
        console.log('NFT collection is empty, seeding with sample data...');
        const sampleNFTs = this.generateRandomNFTs(3);
        await collection.insertMany(sampleNFTs);
        console.log('Added sample NFTs to database');
      } else {
        console.log(`Database already contains ${count} NFTs`);
      }
    } catch (error) {
      console.error('Error initializing database:', error);
      throw error;
    }
  }

  // Get all NFT listings
  async getAllListings(): Promise<NFTListing[]> {
    try {
      const collection = await this.getCollection();
      const listings = await collection.find({}).toArray();
      return listings.map(listing => {
        // Convert MongoDB ObjectId to string if present
        return {
          ...listing,
          _id: listing._id?.toString()
        };
      });
    } catch (error) {
      console.error('Error getting listings:', error);
      throw error;
    }
  }

  // Add a new NFT listing
  async addListing(listing: NFTListing): Promise<string> {
    try {
      const collection = await this.getCollection();
      const result = await collection.insertOne(listing);
      return result.insertedId.toString();
    } catch (error) {
      console.error('Error adding listing:', error);
      throw error;
    }
  }

  // Remove an NFT listing
  async removeListing(id: string): Promise<boolean> {
    try {
      const collection = await this.getCollection();
      const result = await collection.deleteOne({ id });
      return result.deletedCount > 0;
    } catch (error) {
      console.error('Error removing listing:', error);
      throw error;
    }
  }

  // Close MongoDB connection
  async close(): Promise<void> {
    if (this.client) {
      await this.client.close();
      this.connected = false;
      console.log('MongoDB connection closed');
    }
  }
}

// Export singleton instance
export const mongoDBService = new MongoDBService();