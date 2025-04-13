"use client";

import { useState } from "react";
import Link from "next/link";
import type { NextPage } from "next";
import { useAccount } from "wagmi";
import { PlusIcon } from "@heroicons/react/24/outline";
import { Address } from "~~/components/scaffold-eth";
import { MarketplaceList } from "~~/components/marketplace/MarketplaceList";
import NFTCreatorModal from "~~/components/marketplace/NFTCreatorModal";

const Home: NextPage = () => {
  const { address: connectedAddress } = useAccount();
  const [isModalOpen, setIsModalOpen] = useState(false);

  return (
    <>
      <div className="flex items-center flex-col flex-grow pt-10">
        <div className="w-full max-w-7xl px-5">
          <div className="flex justify-between items-center mb-8">
            <h1 className="text-4xl font-bold">NFT Marketplace</h1>
            
            {connectedAddress && (
              <button
                onClick={() => setIsModalOpen(true)}
                className="btn btn-primary flex items-center"
              >
                <PlusIcon className="h-5 w-5 mr-1" />
                Add NFT
              </button>
            )}
            
            {!connectedAddress && (
              <div className="text-sm opacity-70">
                Connect wallet to create NFTs
              </div>
            )}
          </div>
          
          {/* NFT Creator Modal */}
          {isModalOpen && <NFTCreatorModal isOpen={isModalOpen} onClose={() => setIsModalOpen(false)} />}
          
          {/* Display connected address */}
          <div className="flex justify-end items-center mb-8">
            <div className="flex items-center">
              <span className="mr-2 text-sm opacity-70">Connected as:</span>
              <Address address={connectedAddress} />
            </div>
          </div>
          
          {/* NFT Marketplace Listings */}
          <MarketplaceList />
        </div>
      </div>
    </>
  );
};

export default Home;
