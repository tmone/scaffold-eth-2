"use client";

import { useEffect } from 'react';

/**
 * A component that logs user interactions to make them visible in the console
 * This helps with QC testing and monitoring user flows
 */
const UserActionLogger = () => {
  useEffect(() => {
    // Function to log user interactions
    const logUserAction = (event: MouseEvent | SubmitEvent) => {
      const target = event.target as HTMLElement;
      if (!target) return;
      
      let actionType = event.type;
      let elementType = target.tagName.toLowerCase();
      let elementText = '';
      let elementId = target.id || '';
      let elementClass = target.className?.toString() || '';
      
      // Try to get text content or value
      if (target instanceof HTMLInputElement || target instanceof HTMLTextAreaElement || target instanceof HTMLSelectElement) {
        elementText = (target as HTMLInputElement).value || 'empty';
      } else {
        elementText = target.textContent?.trim() || 'empty';
      }
      
      // Limit the length of text
      if (elementText.length > 30) {
        elementText = elementText.substring(0, 30) + '...';
      }
      
      // Check for NFT related actions
      const isNFTAction = 
        elementText.toLowerCase().includes('nft') || 
        elementText.toLowerCase().includes('mint') ||
        elementText.toLowerCase().includes('buy') ||
        elementText.toLowerCase().includes('sell') ||
        elementText.toLowerCase().includes('list') ||
        elementClass.toLowerCase().includes('nft');
      
      // Create a formatted message for the console
      const logMessage = `USER ACTION: ${actionType} on ${elementType}${elementId ? '#'+elementId : ''}${elementClass ? '.'+elementClass.split(' ')[0] : ''} - Text: "${elementText}"${isNFTAction ? ' [NFT]' : ''}`;
      
      // Log to console with timestamp
      console.log(`[${new Date().toISOString()}] ${logMessage}`);
    };
    
    // Function to log form submissions
    const logFormSubmit = (event: SubmitEvent) => {
      const form = event.target as HTMLFormElement;
      if (!form) return;
      
      const formId = form.id || 'unnamed';
      const formAction = form.action || 'no-action';
      
      // Log form submission with fields
      let formFields = '';
      try {
        Array.from(form.elements).forEach((element) => {
          if (element instanceof HTMLInputElement || element instanceof HTMLTextAreaElement || element instanceof HTMLSelectElement) {
            const field = element as HTMLInputElement;
            if (field.name && !field.name.toLowerCase().includes('password')) {
              formFields += `${field.name}=${field.value.substring(0, 20)}; `;
            }
          }
        });
      } catch (err) {
        formFields = 'Error collecting form fields';
      }
      
      console.log(`[${new Date().toISOString()}] USER ACTION: form_submit on form#${formId} to ${formAction} - Fields: ${formFields}`);
    };
    
    // Function to log wallet actions and transactions
    const logWalletActions = () => {
      // Track wallet connections
      const checkWallet = setInterval(() => {
        // Look for wallet address in the DOM
        try {
          const addressElements = document.querySelectorAll('[data-address], [data-wallet], .wallet-address, .address');
          addressElements.forEach(element => {
            const text = element.textContent || '';
            if (text.match(/0x[a-fA-F0-9]{6,40}/)) {
              console.log(`[${new Date().toISOString()}] WALLET: Address detected - ${text.substring(0, 12)}...`);
            }
          });
          
          // Look for transaction-related elements
          const txElements = document.querySelectorAll('[data-tx], [data-transaction], .transaction');
          txElements.forEach(element => {
            const text = element.textContent || '';
            if (text.match(/0x[a-fA-F0-9]{6,40}/)) {
              console.log(`[${new Date().toISOString()}] WALLET: Transaction detected - ${text.substring(0, 12)}...`);
            }
          });
        } catch (err) {
          // Silent fail
        }
      }, 3000); // Check every 3 seconds
      
      return () => clearInterval(checkWallet);
    };
    
    // Function to log NFT-related operations
    const logNFTOperations = () => {
      // Create a mutation observer to detect NFT cards and listings
      const observer = new MutationObserver((mutations) => {
        mutations.forEach(mutation => {
          if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
            mutation.addedNodes.forEach(node => {
              if (node instanceof HTMLElement) {
                // Check if this is an NFT card/item
                if (node.classList.contains('nft-item') || 
                    node.classList.contains('nft-card') || 
                    node.innerHTML?.includes('NFT') ||
                    node.innerHTML?.includes('token') ||
                    node.innerHTML?.includes('asset')
                ) {
                  // Try to extract NFT ID or name
                  const nftId = node.getAttribute('data-id') || 'unknown';
                  const nftName = node.querySelector('[data-name], .nft-name')?.textContent || 'Unknown NFT';
                  console.log(`[${new Date().toISOString()}] USER ACTION: NFT item loaded - ID: ${nftId}, Name: ${nftName}`);
                }
              }
            });
          }
        });
      });
      
      // Start observing
      observer.observe(document.body, {
        childList: true,
        subtree: true,
      });
      
      return () => observer.disconnect();
    };
    
    // Register basic event listeners for user interactions
    document.addEventListener('click', logUserAction as EventListener);
    document.addEventListener('submit', logFormSubmit as EventListener);
    
    // Monitor wallet and NFT operations
    const walletCleanup = logWalletActions();
    const nftCleanup = logNFTOperations();
    
    // Log initial page load
    console.log(`[${new Date().toISOString()}] USER ACTION: page_load - ${window.location.pathname}`);
    
    return () => {
      // Clean up event listeners on unmount
      document.removeEventListener('click', logUserAction as EventListener);
      document.removeEventListener('submit', logFormSubmit as EventListener);
      walletCleanup();
      nftCleanup();
    };
  }, []);
  
  return null; // This component doesn't render anything
};

export default UserActionLogger;