import { NextRequest, NextResponse } from 'next/server';
import { NFTListing } from '../../../types/marketplace';

// In-memory storage for listings (in a real app, this would be a database)
const MOCK_LISTINGS: NFTListing[] = [
  {
    id: '1',
    tokenId: '1',
    contractAddress: '0x5FbDB2315678afecb367f032d93F642f64180aa3', // OpenSeaQcNFT address
    price: '0.01',
    seller: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266', // Default Hardhat account 0
    name: 'Demo NFT #1',
    description: 'This is a demo NFT for testing purposes',
    imageUrl: 'https://placehold.co/600x400?text=NFT+Demo+1',
    tokenType: 'ERC721',
    createdAt: Date.now() - 1000000,
    updatedAt: Date.now() - 1000000
  },
  {
    id: '2',
    tokenId: '2',
    contractAddress: '0x5FbDB2315678afecb367f032d93F642f64180aa3', // OpenSeaQcNFT address
    price: '0.02',
    seller: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266', // Default Hardhat account 0
    name: 'Demo NFT #2',
    description: 'This is another demo NFT for testing purposes',
    imageUrl: 'https://placehold.co/600x400?text=NFT+Demo+2',
    tokenType: 'ERC721',
    createdAt: Date.now() - 500000,
    updatedAt: Date.now() - 500000
  },
  {
    id: '3',
    tokenId: '1',
    contractAddress: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512', // Example ERC1155 address
    price: '0.005',
    seller: '0x70997970C51812dc3A010C7d01b50e0d17dc79C8', // Default Hardhat account 1
    name: 'Multi-token NFT #1',
    description: 'This is an ERC1155 NFT with multiple copies',
    imageUrl: 'https://placehold.co/600x400?text=Multi+Token',
    tokenType: 'ERC1155',
    amount: 5, // 5 copies available
    createdAt: Date.now() - 200000,
    updatedAt: Date.now() - 200000
  }
];

// GET all listings
export async function GET(request: NextRequest) {
  try {
    // Add artificial delay to simulate network conditions
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // Return all listings
    return NextResponse.json(MOCK_LISTINGS);
  } catch (error) {
    console.error('Error in GET /api/listings:', error);
    return NextResponse.json(
      { error: 'Failed to fetch listings' },
      { status: 500 }
    );
  }
}

// POST to create a new listing
export async function POST(request: NextRequest) {
  try {
    const data = await request.json();
    
    // Validate required fields
    if (!data.tokenId || !data.contractAddress || !data.price || !data.seller || !data.name) {
      return NextResponse.json(
        { error: 'Missing required fields' },
        { status: 400 }
      );
    }
    
    // Create new listing
    const newListing: NFTListing = {
      id: `${MOCK_LISTINGS.length + 1}`, // Generate simple ID
      ...data,
      createdAt: Date.now(),
      updatedAt: Date.now()
    };
    
    // In a real app, save to database
    MOCK_LISTINGS.push(newListing);
    
    return NextResponse.json(newListing, { status: 201 });
  } catch (error) {
    console.error('Error in POST /api/listings:', error);
    return NextResponse.json(
      { error: 'Failed to create listing' },
      { status: 500 }
    );
  }
}