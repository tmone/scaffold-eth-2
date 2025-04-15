/**
 * IPFS utility functions for NFT image handling
 */

/**
 * Generate a mock IPFS CID that is valid for testing
 * These are real IPFS CIDs that point to test images in IPFS
 * @returns A valid IPFS CID
 */
export const generateMockIpfsCid = (): string => {
  // These are real IPFS CIDs that point to test images
  const validTestCids = [
    'QmNwrd7WxH1HSC7iKsZK2Kz9LzA9EKtP4m2RXs7cA8sHEE',
    'QmPbxeGcXhYQQNgsC6a36dDyYUcHgMLnGKnF8pVFmGsvqi',
    'QmcJwbxBCHvFG7JQNTWaAEHqWvmq1KVxj8zWqFc3nPMiPM',
    'QmT5NvUtoM5nWFfrQdVrFtvGfKFmG7AHE8P34isapyhCxX',
    'QmV9tSDx9UiPeWExXEeH6aoDvmihvx6jD5eLb4jbTaKGps'
  ];
  
  // Pick a random CID from the valid test CIDs
  return validTestCids[Math.floor(Math.random() * validTestCids.length)];
};

/**
 * Convert an IPFS URI to a HTTP URL using a public gateway
 * @param ipfsUri IPFS URI (ipfs://...)
 * @returns HTTP URL for the IPFS content
 */
export const ipfsUriToGatewayUrl = (ipfsUri: string): string => {
  if (!ipfsUri) return '';
  
  // Handle ipfs:// protocol
  if (ipfsUri.startsWith('ipfs://')) {
    return ipfsUri.replace('ipfs://', 'https://ipfs.io/ipfs/');
  }
  
  return ipfsUri;
};

/**
 * Get a display URL for an image that might be an IPFS URI
 * @param url The image URL or IPFS URI
 * @returns A URL that can be used in img src attributes
 */
export const getDisplayImageUrl = (url: string): string => {
  if (!url) return '';
  
  // Handle ipfs:// protocol
  if (url.startsWith('ipfs://')) {
    return ipfsUriToGatewayUrl(url);
  }
  
  return url;
};