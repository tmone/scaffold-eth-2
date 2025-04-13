# OpenSea QC Marketplace

Dự án xây dựng marketplace NFT tương tự OpenSea dành cho mục đích kiểm thử QC, tích hợp toàn diện các thành phần public của OpenSea và sử dụng các module tương tự cho các phần không công khai.

## Mục lục

- [Tổng quan](#tổng-quan)
- [Kiến trúc dự án](#kiến-trúc-dự-án)
- [Yêu cầu hệ thống](#yêu-cầu-hệ-thống)
- [Thiết lập môi trường WSL](#thiết-lập-môi-trường-wsl)
- [Cài đặt công cụ phát triển](#cài-đặt-công-cụ-phát-triển)
- [Tích hợp các thành phần OpenSea](#tích-hợp-các-thành-phần-opensea)
  - [Seaport Protocol](#seaport-protocol)
  - [OpenSea NFT Contracts](#opensea-nft-contracts)
  - [OpenSea JS SDK](#opensea-js-sdk)
  - [Các thành phần bổ sung](#các-thành-phần-bổ-sung)
- [Tích hợp Scaffold-ETH 2](#tích-hợp-scaffold-eth-2)
  - [Token hóa Image thành NFT](#token-hóa-image-thành-nft)
  - [Marketplace UI](#marketplace-ui)
- [Cấu hình cơ sở dữ liệu](#cấu-hình-cơ-sở-dữ-liệu)
- [Phát triển giao diện người dùng](#phát-triển-giao-diện-người-dùng)
- [Triển khai các chức năng chính](#triển-khai-các-chức-năng-chính)
- [Kiểm thử](#kiểm-thử)
- [Khắc phục sự cố](#khắc-phục-sự-cố)
- [Đóng góp](#đóng-góp)

## Tổng quan

Dự án này xây dựng một nền tảng marketplace NFT giống OpenSea để cung cấp môi trường kiểm thử QC đầy đủ. Chúng tôi tích hợp:

- **Seaport Protocol**: Protocol chính thức của OpenSea cho marketplace NFT, sử dụng trực tiếp từ repository gốc
- **OpenSea NFT Contracts**: Các hợp đồng NFT công khai của OpenSea
- **OpenSea JS SDK**: Thư viện JavaScript chính thức để tương tác với API và smart contracts
- **Scaffold-ETH 2**: Framework để xây dựng giao diện token hóa image thành NFT và marketplace
- **Các thành phần thay thế**: Cho các module không công khai của OpenSea
- **WSL2**: Windows Subsystem for Linux để cung cấp môi trường phát triển thống nhất
- **Docker**: Để triển khai các dịch vụ cơ sở dữ liệu

## Kiến trúc dự án

Dự án được tổ chức theo mô hình module với các thành phần riêng biệt để tránh xung đột phiên bản Solidity:

```
opensea-qc/
├── components/                # Các module riêng biệt
│   ├── seaport/               # Tích hợp Seaport protocol từ repo gốc
│   ├── erc721/                # Smart contracts ERC-721
│   ├── erc1155/               # Smart contracts ERC-1155
│   └── operator-filter/       # Operator Filter Registry
├── packages/
│   ├── hardhat/               # Môi trường phát triển Hardhat
│   │   └── contracts/         # Các smart contracts
│   └── nextjs/                # Giao diện người dùng (từ Scaffold-ETH 2)
│       ├── components/        # React components
│       │   ├── marketplace/   # Components cho marketplace
│       │   └── nft/           # Components để tạo và quản lý NFT
│       └── pages/             # Các trang của ứng dụng
├── scripts/                   # Scripts tiện ích và deployment
│   ├── build-and-deploy-all.sh # Script tự động build và deploy tất cả components
│   └── ...
└── docker/                    # Cấu hình Docker cho các dịch vụ
    └── docker-compose.yml     # Cấu hình Docker Compose
```

## Yêu cầu hệ thống

- Windows 11 với WSL2 được kích hoạt
- Tối thiểu 8GB RAM
- 50GB ổ đĩa trống
- Visual Studio Code
- Docker Desktop cho Windows (tùy chọn nếu sử dụng Docker trong WSL)

## Thiết lập môi trường WSL

### 1. Cài đặt Ubuntu 22.04 LTS trên WSL2

```powershell
# Mở PowerShell với quyền Administrator
wsl --install -d Ubuntu-22.04
```

### 2. Đảm bảo WSL2 được sử dụng

```powershell
# Kiểm tra phiên bản
wsl -l -v

# Nếu không phải WSL2, hãy chuyển đổi
wsl --set-version Ubuntu-22.04 2
```

### 3. Tối ưu hóa WSL2

Tạo file `.wslconfig` trong thư mục người dùng Windows (`C:\Users\YourUsername\.wslconfig`):

```ini
[wsl2]
memory=8GB
processors=4
swap=4GB
localhostForwarding=true
```

### 4. Khởi động Ubuntu WSL

```powershell
wsl -d Ubuntu-22.04
```

## Cài đặt công cụ phát triển

### 1. Cập nhật hệ thống

```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Cài đặt các công cụ cơ bản

```bash
sudo apt install -y build-essential curl file git python3-pip jq
```

### 3. Cài đặt Node.js và Yarn

```bash
# Cài đặt NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
source ~/.bashrc

# Cài đặt Node.js
nvm install 18
nvm use 18
nvm alias default 18

# Cài đặt Yarn
npm install -g yarn
```

### 4. Cài đặt Docker và Docker Compose

```bash
# Cài đặt dependencies
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# Thêm Docker repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Cài đặt Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose

# Thêm user vào group docker
sudo usermod -aG docker $USER

# Khởi động Docker service
sudo service docker start

# Kiểm tra Docker đã hoạt động
docker --version
docker-compose --version
```

Lưu ý: Khởi động lại shell hoặc chạy `newgrp docker` để áp dụng thay đổi group.

### 5. Cài đặt các công cụ phát triển blockchain

```bash
# Cài đặt Hardhat và các công cụ khác
npm install -g hardhat truffle ganache

# Cài đặt Foundry
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup
```

### 6. Thiết lập VS Code

Cài đặt VS Code trên Windows và các extension:
- Remote - WSL
- Solidity
- Docker
- GitLens

Mở VS Code và kết nối với WSL:
1. Nhấn `F1` và tìm "Remote-WSL: New Window"
2. VS Code sẽ mở cửa sổ mới kết nối với WSL

## Tích hợp các thành phần OpenSea

### Seaport Protocol

Seaport là protocol chính của OpenSea để xử lý tất cả các giao dịch NFT (listing, buying, offering, bidding).

```bash
# Clone Seaport repository với submodules
cd ~/opensea-qc/components/seaport
git clone --recurse-submodules https://github.com/ProjectOpenSea/seaport.git .
yarn install
yarn build

# Chạy tests để đảm bảo mọi thứ hoạt động
yarn test

# Tạo báo cáo coverage
yarn coverage
```

#### Chạy Foundry Tests cho Seaport

```bash
cd ~/opensea-qc/components/seaport

# Build phiên bản tối ưu
FOUNDRY_PROFILE=optimized forge build

# Chạy tests với trace đầy đủ
FOUNDRY_PROFILE=debug forge test -vvv

# Chạy báo cáo coverage
SEAPORT_COVERAGE=true forge coverage --report summary --report lcov && lcov -o lcov.info --remove lcov.info --rc lcov_branch_coverage=1 --rc lcov_function_coverage=1 "test/*" "script/*" && genhtml lcov.info -o html --branch
```

### OpenSea NFT Contracts

Tích hợp các hợp đồng NFT của OpenSea để sử dụng trong môi trường kiểm thử.

#### 1. Tích hợp OpenSea ERC721

```bash
# Clone opensea-creatures repository (mẫu ERC721)
cd ~/opensea-qc/components/erc721
git clone https://github.com/ProjectOpenSea/opensea-creatures.git .
yarn install
```

#### 2. Tích hợp OpenSea ERC1155

```bash
# Tạo thư mục cho ERC1155
cd ~/opensea-qc/components/erc1155
mkdir -p contracts

# Tạo contract ERC1155 hiện đại
cat > contracts/ModernERC1155.sol << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract ModernERC1155 is ERC1155, Ownable {
    using Strings for string;
    
    string public name;
    string public symbol;
    
    mapping(uint256 => string) private _tokenURIs;
    
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) ERC1155(_uri) {
        name = _name;
        symbol = _symbol;
    }
    
    function mint(address to, uint256 id, uint256 amount, bytes memory data) 
        public onlyOwner 
    {
        _mint(to, id, amount, data);
    }
    
    function batchMint(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }
    
    function setURI(uint256 id, string memory newTokenURI) public onlyOwner {
        _tokenURIs[id] = newTokenURI;
    }
    
    function uri(uint256 id) public view override returns (string memory) {
        string memory tokenURI = _tokenURIs[id];
        
        // If token has specific URI, return it
        if (bytes(tokenURI).length > 0) {
            return tokenURI;
        }
        
        // Otherwise return baseURI + id
        return string(abi.encodePacked(super.uri(id), Strings.toString(id)));
    }
}
EOF

# Cài đặt dependencies
yarn add @openzeppelin/contracts
```

#### 3. Tích hợp Operator Filter Registry

```bash
# Clone repository
cd ~/opensea-qc/components/operator-filter
git clone https://github.com/ProjectOpenSea/operator-filter-registry.git .
yarn install
```

### OpenSea JS SDK

Tích hợp SDK chính thức của OpenSea để tương tác với API và smart contracts.

```bash
# Tạo thư mục cho SDK
cd ~/opensea-qc/packages/nextjs
yarn add opensea-js ethers@^5.7.2 web3

# Tạo wrapper service cho OpenSea SDK
mkdir -p utils/opensea
```

Tạo file `utils/opensea/opensea-service.js`:

```javascript
import { OpenSeaSDK, Network } from 'opensea-js';
import { ethers } from 'ethers';

class OpenSeaService {
  constructor(provider, network = Network.Goerli) {
    this.provider = provider;
    this.openseaSDK = new OpenSeaSDK(provider, {
      network,
      apiKey: process.env.OPENSEA_API_KEY // Tùy chọn
    });
  }
  
  // Các hàm wrapper và tiện ích
  async createListing(asset, accountAddress, startAmount, endAmount = null, expirationTime = null) {
    // ...
  }
  
  async fulfillOrder(order, accountAddress) {
    // ...
  }
  
  // Các hàm khác
}

export default OpenSeaService;
```

### Các thành phần bổ sung

#### IPFS cho metadata

```bash
# Cài đặt IPFS dependencies
cd ~/opensea-qc/packages/nextjs
yarn add ipfs-http-client web3.storage react-dropzone
```

## Tích hợp Scaffold-ETH 2

### Thiết lập Scaffold-ETH 2

```bash
cd ~/opensea-qc
npx create-eth@latest
```

### Token hóa Image thành NFT

Sử dụng các components của Scaffold-ETH 2 để xây dựng giao diện token hóa image thành NFT:

1. **Tạo component NFT Creator**:

```jsx
// packages/nextjs/components/nft/NFTCreator.tsx
import { useCallback, useState } from "react";
import { useDropzone } from "react-dropzone";
import { Web3Storage } from "web3.storage";
import { useAccount } from "wagmi";
import { useScaffoldContractWrite } from "~~/hooks/scaffold-eth";

const web3Storage = new Web3Storage({ token: "YOUR_WEB3_STORAGE_TOKEN" });

export const NFTCreator = () => {
  const { address } = useAccount();
  const [image, setImage] = useState(null);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [uploading, setUploading] = useState(false);

  // Kết nối với smart contract
  const { writeAsync: mintNFT, isLoading } = useScaffoldContractWrite({
    contractName: "YourNFT",
    functionName: "mintItem",
    args: [address, ""],
  });

  // Xử lý khi thả file
  const onDrop = useCallback(acceptedFiles => {
    setImage(acceptedFiles[0]);
  }, []);

  const { getRootProps, getInputProps } = useDropzone({ 
    onDrop,
    accept: {
      'image/*': ['.jpeg', '.jpg', '.png', '.gif']
    }
  });

  // Function để mint NFT
  const createNFT = async () => {
    if (!image || !name || !address) return;

    try {
      setUploading(true);

      // 1. Upload ảnh lên IPFS
      const imageFile = new File([image], image.name, { type: image.type });
      const imageCid = await web3Storage.put([imageFile]);
      const imageURI = `ipfs://${imageCid}/${image.name}`;

      // 2. Tạo và upload metadata
      const metadata = {
        name,
        description,
        image: imageURI,
      };
      
      const metadataFile = new File(
        [JSON.stringify(metadata)], 
        'metadata.json', 
        { type: 'application/json' }
      );
      
      const metadataCid = await web3Storage.put([metadataFile]);
      const metadataURI = `ipfs://${metadataCid}/metadata.json`;

      // 3. Mint NFT với URI metadata
      await mintNFT({ args: [address, metadataURI] });

      setName("");
      setDescription("");
      setImage(null);
    } catch (error) {
      console.error("Error creating NFT:", error);
    } finally {
      setUploading(false);
    }
  };

  // Component UI code...
};
```

2. **Tạo trang NFT Creator**:

```jsx
// packages/nextjs/pages/nft-creator.tsx
import type { NextPage } from "next";
import { MetaHeader } from "~~/components/MetaHeader";
import { NFTCreator } from "~~/components/nft/NFTCreator";

const NFTCreatorPage: NextPage = () => {
  return (
    <>
      <MetaHeader title="NFT Creator" />
      <div className="flex items-center flex-col pt-10">
        <h1 className="text-4xl font-bold">NFT Creator</h1>
        <NFTCreator />
      </div>
    </>
  );
};

export default NFTCreatorPage;
```

### Marketplace UI

Sử dụng Scaffold-ETH 2 và Seaport để xây dựng giao diện marketplace:

1. **Tạo component Marketplace**:

```jsx
// packages/nextjs/components/marketplace/MarketplaceList.tsx
import { useState, useEffect } from "react";
import { useAccount } from "wagmi";
import { NFTCard } from "./NFTCard";
import { useSeaport } from "~~/hooks/useSeaport";

export const MarketplaceList = () => {
  const { address } = useAccount();
  const [listings, setListings] = useState([]);
  const [loading, setLoading] = useState(true);
  const { getListings } = useSeaport();

  useEffect(() => {
    const fetchListings = async () => {
      if (!address) return;
      
      try {
        setLoading(true);
        const activeListings = await getListings();
        setListings(activeListings);
      } catch (error) {
        console.error("Error fetching listings:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchListings();
  }, [address, getListings]);

  if (loading) {
    return <div className="animate-pulse">Loading listings...</div>;
  }

  if (listings.length === 0) {
    return <div>No active listings found.</div>;
  }

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
      {listings.map((listing) => (
        <NFTCard 
          key={listing.id}
          id={listing.id}
          name={listing.name}
          image={listing.image}
          price={listing.price}
          collection={listing.collection}
        />
      ))}
    </div>
  );
};
```

2. **Tạo hook useSeaport để tương tác với Seaport protocol**:

```typescript
// packages/nextjs/hooks/useSeaport.ts
import { useState, useCallback } from "react";
import { ethers } from "ethers";
import { useProvider, useSigner } from "wagmi";
import { Seaport } from "@opensea/seaport-js";

export const useSeaport = () => {
  const provider = useProvider();
  const { data: signer } = useSigner();
  const [seaport, setSeaport] = useState<Seaport | null>(null);

  // Khởi tạo Seaport
  const initializeSeaport = useCallback(async () => {
    if (!signer) return null;
    
    const seaportInstance = new Seaport(signer);
    setSeaport(seaportInstance);
    return seaportInstance;
  }, [signer]);

  // Lấy danh sách các listings
  const getListings = useCallback(async () => {
    const seaportInstance = seaport || await initializeSeaport();
    if (!seaportInstance) return [];
    
    // Implement logic to fetch listings from Seaport
    // This is a simplified example
    return [];
  }, [seaport, initializeSeaport]);

  // Tạo listing mới
  const createListing = useCallback(async (params) => {
    const seaportInstance = seaport || await initializeSeaport();
    if (!seaportInstance) throw new Error("Seaport not initialized");
    
    // Implement create listing logic
  }, [seaport, initializeSeaport]);

  // Mua NFT từ listing
  const fulfillListing = useCallback(async (listingId) => {
    const seaportInstance = seaport || await initializeSeaport();
    if (!seaportInstance) throw new Error("Seaport not initialized");
    
    // Implement fulfill listing logic
  }, [seaport, initializeSeaport]);

  return {
    initializeSeaport,
    getListings,
    createListing,
    fulfillListing
  };
};
```

## Cấu hình cơ sở dữ liệu

### 1. Tạo docker-compose.yml

Tạo thư mục `docker` và file `docker/docker-compose.yml`:

```bash
mkdir -p docker
```

```yaml
# docker/docker-compose.yml
version: '3.8'
services:
  mongodb:
    image: mongo:latest
    container_name: opensea-mongodb
    ports:
      - "27017:27017"
    volumes:
      - mongodb_data:/data/db
    restart: unless-stopped
      
  postgres:
    image: postgres:14
    container_name: opensea-postgres
    environment:
      POSTGRES_PASSWORD: yourpassword
      POSTGRES_USER: opensea
      POSTGRES_DB: opensea_db
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped
      
  redis:
    image: redis:latest
    container_name: opensea-redis
    ports:
      - "6379:6379"
    restart: unless-stopped

  # Component cho full-text search
  elasticsearch:
    image: elasticsearch:7.17.0
    container_name: opensea-elasticsearch
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    ports:
      - "9200:9200"
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    restart: unless-stopped

  # IPFS node cho lưu trữ metadata
  ipfs:
    image: ipfs/kubo:latest
    container_name: opensea-ipfs
    ports:
      - "4001:4001"
      - "5001:5001"
      - "8080:8080"
    volumes:
      - ipfs_data:/data/ipfs
    restart: unless-stopped

volumes:
  mongodb_data:
  postgres_data:
  elasticsearch_data:
  ipfs_data:
```

### 2. Khởi động cơ sở dữ liệu

```bash
cd docker
docker-compose up -d
```

## Phát triển giao diện người dùng

### 1. Tạo trang chủ marketplace

Chỉnh sửa `packages/nextjs/pages/index.tsx` để tạo trang chủ marketplace:

```jsx
import { useState } from "react";
import type { NextPage } from "next";
import { MetaHeader } from "~~/components/MetaHeader";
import { MarketplaceList } from "~~/components/marketplace/MarketplaceList";

const Home: NextPage = () => {
  const [isTestMode, setIsTestMode] = useState(false);

  return (
    <>
      <MetaHeader />
      <div className="flex flex-col items-center pt-10">
        <div className="px-5">
          <h1 className="text-center mb-6">
            <span className="block text-4xl font-bold">OpenSea QC Marketplace</span>
          </h1>
          <div className="flex justify-center mb-6">
            <label className="cursor-pointer label">
              <span className="label-text mr-3">Test Mode</span> 
              <input 
                type="checkbox" 
                className="toggle toggle-primary" 
                checked={isTestMode}
                onChange={() => setIsTestMode(!isTestMode)}
              />
            </label>
          </div>
        </div>

        {isTestMode && (
          <div className="bg-base-300 w-full max-w-3xl mx-auto rounded-xl p-4 mb-6">
            <h2 className="text-xl font-bold mb-2">QC Test Panel</h2>
            <p>Enable testing functionality for marketplace contracts</p>
            <div className="mt-4 flex space-x-2">
              <button className="btn btn-sm btn-primary">Run Basic Tests</button>
              <button className="btn btn-sm btn-secondary">Deploy Test NFT</button>
            </div>
          </div>
        )}

        <div className="w-full max-w-7xl mx-auto px-6">
          <MarketplaceList />
        </div>
      </div>
    </>
  );
};

export default Home;
```

## Triển khai các chức năng chính

### 1. Tạo chức năng tạo và liệt kê NFT

Sử dụng Scaffold-ETH 2 và OpenSea contracts để xây dựng chức năng mint NFT

### 2. Xây dựng chức năng mua bán NFT

Sử dụng Seaport protocol để triển khai các chức năng giao dịch

### 3. Phát triển chức năng đấu giá

Triển khai chức năng auction sử dụng Seaport protocol

### 4. Thêm bảng điều khiển kiểm thử

Xây dựng UI để kiểm thử tất cả chức năng một cách trực quan

## Kiểm thử

### 1. Viết unit tests cho hợp đồng thông minh

```bash
# Kiểm thử Seaport
cd ~/opensea-qc/components/seaport
yarn test

# Kiểm thử ERC-721
cd ~/opensea-qc/components/erc721
yarn test

# Kiểm thử ERC-1155
cd ~/opensea-qc/components/erc1155
yarn test

# Kiểm thử Operator Filter
cd ~/opensea-qc/components/operator-filter
yarn test
```

### 2. Kiểm thử tích hợp tất cả components

```bash
cd ~/opensea-qc
./scripts/build-and-deploy-all.sh
```

### 3. Kiểm thử end-to-end với Cypress

```bash
cd ~/opensea-qc/packages/nextjs
yarn cypress
```

## Khắc phục sự cố

### Vấn đề về biên dịch smart contracts

Các smart contracts từ các dự án khác nhau có thể yêu cầu các phiên bản Solidity khác nhau:

1. **Xung đột phiên bản Solidity**: Sử dụng biên dịch riêng biệt cho từng thành phần
2. **Thiếu dependencies**: Cài đặt thêm các dependencies cần thiết
3. **Lỗi đường dẫn import**: Sửa đường dẫn để phù hợp với cấu trúc thư mục

### Lỗi khi build các node modules

Một số node modules có thể yêu cầu build khi cài đặt:

```bash
# Cài đặt dependencies build
sudo apt-get install -y build-essential python3 make gcc g++

# Xóa node_modules và cài đặt lại
rm -rf node_modules
yarn install
```

### Vấn đề kết nối WSL với Docker

Nếu gặp vấn đề kết nối Docker trong WSL:

```bash
# Kiểm tra Docker daemon đang chạy
sudo service docker status

# Nếu không chạy, khởi động lại
sudo service docker start
```

---

## Đóng góp

Chúng tôi hoan nghênh mọi đóng góp cho dự án OpenSea QC Marketplace. Vui lòng tham khảo [CONTRIBUTING.md](CONTRIBUTING.md) để biết chi tiết về quy trình đóng góp.

## Giấy phép

Dự án này được cấp phép theo giấy phép MIT - xem file [LICENSE.md](LICENSE.md) để biết chi tiết.
