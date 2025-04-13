export type NFTType = 'ERC721' | 'ERC1155';

export interface NFTListing {
  id: string;
  tokenId: string;
  contractAddress: string;
  price: string; // Price in ETH as string
  seller: string; // Seller's address
  name: string;
  description: string;
  imageUrl: string;
  tokenType: NFTType;
  amount?: number; // Used for ERC1155 tokens (quantity)
  createdAt: number; // Timestamp
  updatedAt: number; // Timestamp
}

export interface NFTOrder {
  listingId: string;
  buyer: string;  
  price: string;   // Price in ETH as string
  amount: number;  // Quantity purchased (1 for ERC721, can be more for ERC1155)
  timestamp: number;
}