declare module 'web3.storage' {
  export interface Web3StorageOptions {
    token: string;
    endpoint?: string;
  }

  export class Web3Storage {
    constructor(options: Web3StorageOptions);
    
    /**
     * Uploads files to Web3.Storage
     * @param files - Array of File objects to store
     * @returns CID (Content Identifier) string
     */
    put(files: File[]): Promise<string>;
    
    /**
     * Retrieves files from Web3.Storage by CID
     * @param cid - The CID of the content to retrieve
     */
    get(cid: string): Promise<any>;
    
    /**
     * Lists all uploads for the current account
     */
    list(options?: { before?: string; maxResults?: number }): AsyncIterable<any>;
  }
}
