import { OpenSeaSDK, Network } from 'opensea-js';
import { ethers } from 'ethers';

/**
 * Service wrapper for OpenSea SDK
 * Provides simplified methods for interacting with OpenSea's API and smart contracts
 */
class OpenSeaService {
  /**
   * Initialize the OpenSea service
   * @param {Object} provider - Ethers.js provider
   * @param {String} network - OpenSea network (mainnet, goerli, etc)
   */
  constructor(provider, network = Network.Goerli) {
    this.provider = provider;
    this.openseaSDK = new OpenSeaSDK(provider, {
      network,
      apiKey: process.env.NEXT_PUBLIC_OPENSEA_API_KEY // Optional
    });
  }
  
  /**
   * Create listing for an NFT on OpenSea
   * @param {Object} asset - Asset to list
   * @param {String} accountAddress - Address of the seller
   * @param {Number} startAmount - Starting price in ETH
   * @param {Number} endAmount - Ending price in ETH (for declining auctions)
   * @param {Number} expirationTime - When the listing expires (in seconds)
   * @returns {Promise} - The listing creation transaction
   */
  async createListing(asset, accountAddress, startAmount, endAmount = null, expirationTime = null) {
    // Convert ETH to wei
    const startAmountWei = ethers.utils.parseEther(startAmount.toString());
    let endAmountWei = null;
    
    if (endAmount !== null) {
      endAmountWei = ethers.utils.parseEther(endAmount.toString());
    }
    
    // Set default expiration to 7 days if not provided
    const defaultExpirationSeconds = 7 * 24 * 60 * 60;
    const expirationSeconds = expirationTime || defaultExpirationSeconds;
    const expirationTime2 = Math.round(Date.now() / 1000 + expirationSeconds);
    
    try {
      const listing = await this.openseaSDK.createListing({
        asset: {
          tokenId: asset.tokenId,
          tokenAddress: asset.tokenAddress,
          schemaName: asset.schemaName || "ERC721" // or "ERC1155"
        },
        accountAddress,
        startAmount: startAmountWei,
        endAmount: endAmountWei,
        expirationTime: expirationTime2
      });
      
      return listing;
    } catch (error) {
      console.error("Error creating listing:", error);
      throw error;
    }
  }
  
  /**
   * Fulfill an order on OpenSea (buy an NFT)
   * @param {Object} order - The order to fulfill
   * @param {String} accountAddress - Address of the buyer
   * @returns {Promise} - The fulfillment transaction
   */
  async fulfillOrder(order, accountAddress) {
    try {
      const transaction = await this.openseaSDK.fulfillOrder({
        order,
        accountAddress
      });
      
      return transaction;
    } catch (error) {
      console.error("Error fulfilling order:", error);
      throw error;
    }
  }
  
  /**
   * Create a bundle of NFTs to sell together
   * @param {Array} assets - Array of assets to bundle
   * @param {String} accountAddress - Address of the seller
   * @param {String} bundleName - Name for the bundle
   * @param {String} bundleDescription - Description for the bundle
   * @param {Number} startAmount - Starting price in ETH
   * @param {Number} expirationTime - When the listing expires (in seconds)
   * @returns {Promise} - The bundle creation transaction
   */
  async createBundle(assets, accountAddress, bundleName, bundleDescription, startAmount, expirationTime = null) {
    const startAmountWei = ethers.utils.parseEther(startAmount.toString());
    
    const defaultExpirationSeconds = 7 * 24 * 60 * 60;
    const expirationSeconds = expirationTime || defaultExpirationSeconds;
    const expirationTime2 = Math.round(Date.now() / 1000 + expirationSeconds);
    
    try {
      const bundle = await this.openseaSDK.createBundleListing({
        assets,
        accountAddress,
        bundleName,
        bundleDescription,
        startAmount: startAmountWei,
        expirationTime: expirationTime2
      });
      
      return bundle;
    } catch (error) {
      console.error("Error creating bundle:", error);
      throw error;
    }
  }
  
  /**
   * Get orders for an asset
   * @param {Object} asset - Asset to check orders for
   * @returns {Promise<Array>} - Array of orders
   */
  async getOrders(asset) {
    try {
      const { orders } = await this.openseaSDK.api.getOrders({
        asset_contract_address: asset.tokenAddress,
        token_id: asset.tokenId,
        side: 'ask' // 'ask' for sell orders, 'bid' for buy orders
      });
      
      return orders;
    } catch (error) {
      console.error("Error getting orders:", error);
      throw error;
    }
  }
  
  /**
   * Get assets owned by an account
   * @param {String} accountAddress - Address of the account
   * @param {Object} options - Additional options (limit, offset, etc)
   * @returns {Promise<Array>} - Array of assets
   */
  async getAssets(accountAddress, options = {}) {
    try {
      const assets = await this.openseaSDK.api.getAssets({
        owner: accountAddress,
        ...options
      });
      
      return assets;
    } catch (error) {
      console.error("Error getting assets:", error);
      throw error;
    }
  }
  
  /**
   * Get events for an asset
   * @param {Object} asset - Asset to check events for
   * @returns {Promise<Array>} - Array of events
   */
  async getAssetEvents(asset) {
    try {
      const events = await this.openseaSDK.api.getEvents({
        asset_contract_address: asset.tokenAddress,
        token_id: asset.tokenId,
        limit: 20,
        offset: 0
      });
      
      return events;
    } catch (error) {
      console.error("Error getting asset events:", error);
      throw error;
    }
  }
}

export default OpenSeaService;
