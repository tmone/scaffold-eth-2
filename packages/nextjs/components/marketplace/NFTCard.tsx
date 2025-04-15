import { useState } from "react";
import { useAccount } from "wagmi";
import { useSeaport } from "~~/hooks/useSeaport";
import { getDisplayImageUrl } from "~~/utils/ipfs-helpers";

interface NFTCardProps {
  id: string;
  name: string;
  image: string;
  price: string;
  collection: string;
  owner?: string;
  tokenId?: string;
  tokenAddress?: string;
}

export const NFTCard = ({
  id,
  name,
  image,
  price,
  collection,
  owner,
  tokenId,
  tokenAddress,
}: NFTCardProps) => {
  const { address } = useAccount();
  const { fulfillListing } = useSeaport();
  const [isLoading, setIsLoading] = useState(false);
  const [imageError, setImageError] = useState(false);
  
  // Handle purchase of NFT
  const handlePurchase = async () => {
    if (!address) {
      alert("Please connect your wallet");
      return;
    }
    
    try {
      setIsLoading(true);
      await fulfillListing(id);
      alert(`Successfully purchased ${name}!`);
    } catch (error) {
      console.error("Error purchasing NFT:", error);
      alert("Error purchasing NFT. See console for details.");
    } finally {
      setIsLoading(false);
    }
  };
  
  // Xử lý lỗi hình ảnh và sử dụng ảnh dự phòng
  const handleImageError = () => {
    setImageError(true);
  };

  // Lấy URL hình ảnh phù hợp cho hiển thị
  const imageUrl = imageError ? "/fallback-nft.png" : image;
  
  return (
    <div className="card bg-base-100 shadow-xl overflow-hidden hover:shadow-2xl transition-shadow duration-300">
      {/* Card Image */}
      <figure className="relative h-64 w-full overflow-hidden">
        <img 
          src={imageUrl} 
          alt={name}
          className="w-full h-full object-cover"
          onError={handleImageError}
        />
      </figure>
      
      <div className="card-body p-4">
        {/* Collection Name */}
        <p className="text-xs opacity-70">{collection}</p>
        
        {/* NFT Name */}
        <h2 className="card-title text-lg">{name}</h2>
        
        {/* Price */}
        <div className="flex items-center mt-2">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" className="mr-1">
            <path d="M12 2C6.48 2 2 6.48 2 12C2 17.52 6.48 22 12 22C17.52 22 22 17.52 22 12C22 6.48 17.52 2 12 2ZM12 20C7.59 20 4 16.41 4 12C4 7.59 7.59 4 12 4C16.41 4 20 7.59 20 12C20 16.41 16.41 20 12 20ZM9.97 9.47L7.8 10.21L12 13.14L16.2 10.21L14.03 9.47L12 10.82L9.97 9.47ZM16.2 13.79L12 16.72L7.8 13.79V15.03L12 17.97L16.2 15.03V13.79Z" fill="currentColor"/>
          </svg>
          <span className="font-bold">{price} ETH</span>
        </div>
        
        {/* Buy Button */}
        <div className="card-actions justify-end mt-4">
          <button 
            className="btn btn-primary btn-sm w-full"
            onClick={handlePurchase}
            disabled={isLoading}
          >
            {isLoading ? (
              <>
                <span className="loading loading-spinner loading-xs mr-1"></span>
                Processing...
              </>
            ) : (
              "Buy Now"
            )}
          </button>
        </div>
      </div>
    </div>
  );
};

export default NFTCard;
