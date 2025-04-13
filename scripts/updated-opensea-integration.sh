#!/bin/bash

# Script sửa chữa tích hợp OpenSea cập nhật
echo "=== Bắt đầu sửa chữa tích hợp OpenSea ==="

# Cài đặt OpenZeppelin Contracts
echo "Cài đặt OpenZeppelin Contracts..."
cd ~/opensea-qc/packages/hardhat
yarn add @openzeppelin/contracts

# Clone và copy Seaport
echo "Tích hợp Seaport contracts..."
cd ~/opensea-qc
git clone https://github.com/ProjectOpenSea/seaport.git temp-seaport
mkdir -p packages/hardhat/contracts/seaport
cp -r temp-seaport/contracts/* packages/hardhat/contracts/seaport/
rm -rf temp-seaport

# Clone và copy Operator Filter Registry
echo "Tích hợp Operator Filter Registry..."
git clone https://github.com/ProjectOpenSea/operator-filter-registry.git temp-operator-filter
mkdir -p packages/hardhat/contracts/opensea/operator-filter
cp -r temp-operator-filter/src/* packages/hardhat/contracts/opensea/operator-filter/
rm -rf temp-operator-filter

# Clone và copy opensea-creatures (mẫu NFT ERC721)
echo "Tích hợp opensea-creatures (ERC721)..."
git clone https://github.com/ProjectOpenSea/opensea-creatures.git temp-creatures
mkdir -p packages/hardhat/contracts/opensea/erc721
cp -r temp-creatures/contracts/* packages/hardhat/contracts/opensea/erc721/
rm -rf temp-creatures

# Clone và copy opensea-erc1155 nếu còn tồn tại
echo "Thử tích hợp ERC1155 contracts (nếu còn tồn tại)..."
if git clone https://github.com/ProjectOpenSea/opensea-erc1155.git temp-erc1155 2>/dev/null; then
  mkdir -p packages/hardhat/contracts/opensea/erc1155
  cp -r temp-erc1155/contracts/* packages/hardhat/contracts/opensea/erc1155/
  rm -rf temp-erc1155
  echo "Đã tích hợp ERC1155 contracts thành công."
else
  echo "Repository opensea-erc1155 không tồn tại, bỏ qua."
fi

# Clone metadata-api mẫu
echo "Tích hợp metadata-api mẫu..."
git clone https://github.com/ProjectOpenSea/metadata-api-nodejs.git temp-metadata-api
mkdir -p packages/nextjs/utils/opensea/metadata
cp -r temp-metadata-api/* packages/nextjs/utils/opensea/metadata/
rm -rf temp-metadata-api

# Cài đặt các package frontend
echo "Cài đặt các package frontend..."
cd ~/opensea-qc/packages/nextjs
yarn add opensea-js ethers@^5.7.2 web3 ipfs-http-client @apollo/client graphql

# Tạo hợp đồng mẫu NFT nếu cần (dựa trên ERC721 của OpenZeppelin)
echo "Tạo hợp đồng mẫu NFT từ OpenZeppelin..."
mkdir -p ~/opensea-qc/packages/hardhat/contracts/testing
cat > ~/opensea-qc/packages/hardhat/contracts/testing/TestNFT.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract TestNFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("TestNFT", "TNFT") {}

    function mintNFT(address recipient, string memory tokenURI)
        public
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }
}
EOF

echo "=== Tích hợp hoàn tất! ==="
echo "Lưu ý: Repository '721-platform' không còn tồn tại. Đã sử dụng opensea-creatures làm mẫu NFT thay thế."