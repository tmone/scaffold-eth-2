#!/bin/bash

# Script phân tách dự án OpenSea QC thành các project con - Phiên bản cập nhật
# Tác giả: Claude
# Ngày: April 2025

set -e # Dừng script nếu có lỗi xảy ra

echo "===== Bắt đầu tách dự án OpenSea QC thành các thành phần riêng biệt ====="
WORKSPACE_ROOT=~/opensea-qc

# Tạo backup của workspace hiện tại
echo "[1/8] Tạo backup của workspace hiện tại..."
BACKUP_DIR="${WORKSPACE_ROOT}/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r "${WORKSPACE_ROOT}/packages" "$BACKUP_DIR/" 2>/dev/null || echo "Không thể backup packages folder"
echo "✓ Đã tạo backup tại $BACKUP_DIR"

# Tạo cấu trúc thư mục cho các project con
echo "[2/8] Tạo cấu trúc thư mục cho các project con..."
COMPONENTS_DIR="${WORKSPACE_ROOT}/components"
mkdir -p "${COMPONENTS_DIR}/{seaport,erc721,erc1155,operator-filter}"
echo "✓ Đã tạo thư mục cho các project con tại $COMPONENTS_DIR"

# Seaport component
echo "[3/8] Tạo component Seaport..."
SEAPORT_DIR="${COMPONENTS_DIR}/seaport"
mkdir -p "${SEAPORT_DIR}/contracts"

# Tìm vị trí đúng của Seaport
SEAPORT_LOCATIONS=(
  "${WORKSPACE_ROOT}/packages/hardhat/contracts/seaport"
  "${WORKSPACE_ROOT}/packages/seaport/contracts"
  "${WORKSPACE_ROOT}/packages/seaport"
  "${WORKSPACE_ROOT}/seaport/contracts"
  "${WORKSPACE_ROOT}/seaport"
)

SEAPORT_SOURCE=""
for loc in "${SEAPORT_LOCATIONS[@]}"; do
  echo "Kiểm tra $loc..."
  if [ -d "$loc" ]; then
    SEAPORT_SOURCE="$loc"
    echo "Tìm thấy Seaport tại $SEAPORT_SOURCE"
    break
  fi
done

if [ -z "$SEAPORT_SOURCE" ]; then
  echo "Không tìm thấy thư mục Seaport. Sẽ tự động clone từ GitHub..."
  pushd "${WORKSPACE_ROOT}" > /dev/null
  git clone --recurse-submodules https://github.com/ProjectOpenSea/seaport.git temp-seaport
  SEAPORT_SOURCE="${WORKSPACE_ROOT}/temp-seaport"
  popd > /dev/null
fi

# Copy Seaport contracts
if [ -d "${SEAPORT_SOURCE}/contracts" ]; then
  cp -r "${SEAPORT_SOURCE}/contracts/"* "${SEAPORT_DIR}/contracts/"
  echo "✓ Đã copy contracts từ ${SEAPORT_SOURCE}/contracts"
else
  cp -r "${SEAPORT_SOURCE}/"* "${SEAPORT_DIR}/contracts/" 2>/dev/null || 
  echo "Không thể copy Seaport contracts. Đang tạo file cơ bản..."
  
  # Tạo file đơn giản nếu không thể copy
  cat > "${SEAPORT_DIR}/contracts/Seaport.sol" << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// Placeholder for Seaport contract
contract Seaport {
    address public immutable conduitController;
    
    constructor(address _conduitController) {
        conduitController = _conduitController;
    }
}
EOF

  cat > "${SEAPORT_DIR}/contracts/ConduitController.sol" << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// Placeholder for ConduitController contract
contract ConduitController {
    constructor() {}
}
EOF
fi

# Tạo hardhat.config.ts cho Seaport
cat > "${SEAPORT_DIR}/hardhat.config.ts" << 'EOF'
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-chai-matchers";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.14",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      }
    ],
    overrides: {
      "contracts/conduit/Conduit.sol": {
        version: "0.8.14",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000000,
          },
        },
      },
      "contracts/conduit/ConduitController.sol": {
        version: "0.8.14",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000000,
          },
        },
      },
      "contracts/helpers/TransferHelper.sol": {
        version: "0.8.14",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000000,
          },
        },
      },
    },
  },
  networks: {
    hardhat: {
      chainId: 1337
    },
  },
};

export default config;
EOF

# Tạo package.json cho Seaport
cat > "${SEAPORT_DIR}/package.json" << 'EOF'
{
  "name": "opensea-qc-seaport",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "compile": "hardhat compile",
    "test": "hardhat test",
    "deploy": "hardhat run scripts/deploy.js"
  },
  "devDependencies": {
    "@nomicfoundation/hardhat-chai-matchers": "^2.0.0",
    "@nomicfoundation/hardhat-ethers": "^3.0.0",
    "@nomicfoundation/hardhat-network-helpers": "^1.0.0",
    "@nomicfoundation/hardhat-toolbox": "^4.0.0",
    "@nomicfoundation/hardhat-verify": "^2.0.0",
    "@typechain/ethers-v6": "^0.5.0",
    "@typechain/hardhat": "^9.0.0",
    "@types/chai": "^4.2.0",
    "@types/mocha": "^10.0.1",
    "@types/node": "^20.2.5",
    "chai": "^4.3.7",
    "ethers": "^6.6.0",
    "hardhat": "^2.19.0",
    "hardhat-gas-reporter": "^1.0.8",
    "solidity-coverage": "^0.8.0",
    "ts-node": "^10.9.1",
    "typechain": "^8.3.0",
    "typescript": "^5.0.4"
  },
  "dependencies": {
    "@openzeppelin/contracts": "^4.9.3"
  }
}
EOF

# ERC721 component
echo "[4/8] Tạo component ERC721..."
ERC721_DIR="${COMPONENTS_DIR}/erc721"
mkdir -p "${ERC721_DIR}/contracts"

# Tìm vị trí đúng của ERC721
ERC721_LOCATIONS=(
  "${WORKSPACE_ROOT}/packages/hardhat/contracts/opensea/erc721"
  "${WORKSPACE_ROOT}/packages/hardhat/contracts/erc721"
)

ERC721_SOURCE=""
for loc in "${ERC721_LOCATIONS[@]}"; do
  echo "Kiểm tra $loc..."
  if [ -d "$loc" ]; then
    ERC721_SOURCE="$loc"
    echo "Tìm thấy ERC721 tại $ERC721_SOURCE"
    break
  fi
done

if [ -n "$ERC721_SOURCE" ]; then
  cp -r "${ERC721_SOURCE}/"* "${ERC721_DIR}/contracts/" 2>/dev/null || echo "Không thể copy ERC721 contracts"
else
  echo "Không tìm thấy ERC721 contracts, tạo file mẫu..."
  cat > "${ERC721_DIR}/contracts/ERC721Sample.sol" << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC721Sample is ERC721URIStorage, Ownable {
    constructor() ERC721("Sample NFT", "SNFT") {}
    
    function mint(address to, uint256 tokenId, string memory uri) external onlyOwner {
        _mint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }
}
EOF
fi

# Tạo hardhat.config.ts cho ERC721
cat > "${ERC721_DIR}/hardhat.config.ts" << 'EOF'
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-chai-matchers";
import "@typechain/hardhat";
import "hardhat-gas-reporter";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.5.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      }
    ],
    overrides: {
      "openzeppelin-solidity/contracts/**/*.sol": {
        version: "0.5.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      }
    }
  },
  networks: {
    hardhat: {
      chainId: 1337
    },
  },
};

export default config;
EOF

# Tạo package.json cho ERC721
cat > "${ERC721_DIR}/package.json" << 'EOF'
{
  "name": "opensea-qc-erc721",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "compile": "hardhat compile",
    "test": "hardhat test",
    "deploy": "hardhat run scripts/deploy.js"
  },
  "devDependencies": {
    "@nomicfoundation/hardhat-chai-matchers": "^2.0.0",
    "@nomicfoundation/hardhat-ethers": "^3.0.0",
    "@nomicfoundation/hardhat-network-helpers": "^1.0.0",
    "@nomicfoundation/hardhat-toolbox": "^4.0.0",
    "@nomicfoundation/hardhat-verify": "^2.0.0",
    "@typechain/ethers-v6": "^0.5.0",
    "@typechain/hardhat": "^9.0.0",
    "@types/chai": "^4.2.0",
    "@types/mocha": "^10.0.1",
    "@types/node": "^20.2.5",
    "chai": "^4.3.7",
    "ethers": "^6.6.0",
    "hardhat": "^2.19.0",
    "hardhat-gas-reporter": "^1.0.8",
    "ts-node": "^10.9.1",
    "typechain": "^8.3.0",
    "typescript": "^5.0.4"
  },
  "dependencies": {
    "@openzeppelin/contracts": "^4.9.3",
    "openzeppelin-solidity": "2.5.1"
  }
}
EOF

# ERC1155 component
echo "[5/8] Tạo component ERC1155..."
ERC1155_DIR="${COMPONENTS_DIR}/erc1155"
mkdir -p "${ERC1155_DIR}/contracts"

# Tạo ERC1155 mới thay vì copy từ project cũ (để tránh xung đột phiên bản)
cat > "${ERC1155_DIR}/contracts/ModernERC1155.sol" << 'EOF'
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

# Tạo hardhat.config.ts cho ERC1155
cat > "${ERC1155_DIR}/hardhat.config.ts" << 'EOF'
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-chai-matchers";
import "@typechain/hardhat";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      }
    ],
  },
  networks: {
    hardhat: {
      chainId: 1337
    },
  },
};

export default config;
EOF

# Tạo package.json cho ERC1155
cat > "${ERC1155_DIR}/package.json" << 'EOF'
{
  "name": "opensea-qc-erc1155",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "compile": "hardhat compile",
    "test": "hardhat test",
    "deploy": "hardhat run scripts/deploy.js"
  },
  "devDependencies": {
    "@nomicfoundation/hardhat-chai-matchers": "^2.0.0",
    "@nomicfoundation/hardhat-ethers": "^3.0.0",
    "@nomicfoundation/hardhat-network-helpers": "^1.0.0",
    "@nomicfoundation/hardhat-toolbox": "^4.0.0",
    "@nomicfoundation/hardhat-verify": "^2.0.0",
    "@typechain/ethers-v6": "^0.5.0",
    "@typechain/hardhat": "^9.0.0",
    "@types/chai": "^4.2.0",
    "@types/mocha": "^10.0.1",
    "@types/node": "^20.2.5",
    "chai": "^4.3.7",
    "ethers": "^6.6.0",
    "hardhat": "^2.19.0",
    "hardhat-gas-reporter": "^1.0.8",
    "ts-node": "^10.9.1",
    "typechain": "^8.3.0",
    "typescript": "^5.0.4"
  },
  "dependencies": {
    "@openzeppelin/contracts": "^4.9.3"
  }
}
EOF

# Operator Filter component
echo "[6/8] Tạo component Operator Filter..."
FILTER_DIR="${COMPONENTS_DIR}/operator-filter"
mkdir -p "${FILTER_DIR}/contracts"

# Tìm vị trí của Operator Filter
FILTER_LOCATIONS=(
  "${WORKSPACE_ROOT}/packages/hardhat/contracts/opensea/operator-filter"
)

FILTER_SOURCE=""
for loc in "${FILTER_LOCATIONS[@]}"; do
  echo "Kiểm tra $loc..."
  if [ -d "$loc" ]; then
    FILTER_SOURCE="$loc"
    echo "Tìm thấy Operator Filter tại $FILTER_SOURCE"
    break
  fi
done

if [ -n "$FILTER_SOURCE" ]; then
  # Copy các file không phải upgradeable
  find "${FILTER_SOURCE}" -type f -name "*.sol" | grep -v "upgradeable" | grep -v "Upgradeable" | while read -r file; do
    target_dir="${FILTER_DIR}/contracts/$(dirname "$file" | sed "s|${FILTER_SOURCE}||")"
    mkdir -p "$target_dir"
    cp "$file" "$target_dir/"
    echo "Đã copy $(basename "$file")"
  done
else
  echo "Không tìm thấy Operator Filter contracts, tạo file mẫu..."
  cat > "${FILTER_DIR}/contracts/OperatorFilterRegistry.sol" << 'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract OperatorFilterRegistry {
    mapping(address => bool) private _filteredOperators;
    
    function registerOperator(address operator) external {
        _filteredOperators[operator] = true;
    }
    
    function unregisterOperator(address operator) external {
        _filteredOperators[operator] = false;
    }
    
    function isOperatorFiltered(address operator) external view returns (bool) {
        return _filteredOperators[operator];
    }
}
EOF
fi

# Tạo hardhat.config.ts cho Operator Filter
cat > "${FILTER_DIR}/hardhat.config.ts" << 'EOF'
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-chai-matchers";
import "@typechain/hardhat";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      }
    ],
  },
  networks: {
    hardhat: {
      chainId: 1337
    },
  },
};

export default config;
EOF

# Tạo package.json cho Operator Filter
cat > "${FILTER_DIR}/package.json" << 'EOF'
{
  "name": "opensea-qc-operator-filter",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "compile": "hardhat compile",
    "test": "hardhat test",
    "deploy": "hardhat run scripts/deploy.js"
  },
  "devDependencies": {
    "@nomicfoundation/hardhat-chai-matchers": "^2.0.0",
    "@nomicfoundation/hardhat-ethers": "^3.0.0",
    "@nomicfoundation/hardhat-network-helpers": "^1.0.0",
    "@nomicfoundation/hardhat-toolbox": "^4.0.0",
    "@nomicfoundation/hardhat-verify": "^2.0.0",
    "@typechain/ethers-v6": "^0.5.0",
    "@typechain/hardhat": "^9.0.0",
    "@types/chai": "^4.2.0",
    "@types/mocha": "^10.0.1",
    "@types/node": "^20.2.5",
    "chai": "^4.3.7",
    "ethers": "^6.6.0",
    "hardhat": "^2.19.0",
    "hardhat-gas-reporter": "^1.0.8",
    "ts-node": "^10.9.1",
    "typechain": "^8.3.0",
    "typescript": "^5.0.4"
  },
  "dependencies": {
    "@openzeppelin/contracts": "^4.9.3"
  }
}
EOF

# Tạo file deployment script cho mỗi component
echo "[7/8] Tạo các script deployment..."

# Deployment script cho Seaport
mkdir -p "${SEAPORT_DIR}/scripts"
cat > "${SEAPORT_DIR}/scripts/deploy.js" << 'EOF'
const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying Seaport contracts...");

  try {
    // Deploy ConduitController
    const ConduitController = await ethers.getContractFactory("ConduitController");
    const conduitController = await ConduitController.deploy();
    await conduitController.waitForDeployment();
    const conduitControllerAddress = await conduitController.getAddress();
    console.log("ConduitController deployed to:", conduitControllerAddress);

    // Deploy Seaport using the ConduitController's address
    const Seaport = await ethers.getContractFactory("Seaport");
    const seaport = await Seaport.deploy(conduitControllerAddress);
    await seaport.waitForDeployment();
    const seaportAddress = await seaport.getAddress();
    console.log("Seaport deployed to:", seaportAddress);

    console.log("Deployment completed successfully!");
    
    return { 
      conduitController: conduitControllerAddress, 
      seaport: seaportAddress 
    };
  } catch (error) {
    console.error("Error deploying Seaport contracts:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
EOF

# Deployment script cho ERC721
mkdir -p "${ERC721_DIR}/scripts"
cat > "${ERC721_DIR}/scripts/deploy.js" << 'EOF'
const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying ERC721 NFT contracts...");

  try {
    // Deploy any needed ERC721 contracts here
    // Example (may need to be adjusted based on actual contracts):
    const NFTContract = await ethers.getContractFactory("ERC721Sample");
    const nft = await NFTContract.deploy();
    await nft.waitForDeployment();
    console.log("ERC721Sample deployed to:", await nft.getAddress());
    
    console.log("ERC721 deployment completed successfully!");
  } catch (error) {
    console.error("Error deploying ERC721 contracts:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
EOF

# Deployment script cho ERC1155
mkdir -p "${ERC1155_DIR}/scripts"
cat > "${ERC1155_DIR}/scripts/deploy.js" << 'EOF'
const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying ERC1155 NFT contracts...");

  try {
    // Deploy ModernERC1155
    const ModernERC1155 = await ethers.getContractFactory("ModernERC1155");
    const modernERC1155 = await ModernERC1155.deploy(
      "OpenSea QC NFT Collection",
      "OSQC",
      "https://api.opensea-qc.test/api/token/{id}"
    );
    await modernERC1155.waitForDeployment();
    const nftAddress = await modernERC1155.getAddress();
    console.log("ModernERC1155 deployed to:", nftAddress);

    console.log("ERC1155 deployment completed successfully!");
    
    return { modernERC1155: nftAddress };
  } catch (error) {
    console.error("Error deploying ERC1155 contracts:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
EOF

# Deployment script cho Operator Filter
mkdir -p "${FILTER_DIR}/scripts"
cat > "${FILTER_DIR}/scripts/deploy.js" << 'EOF'
const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying Operator Filter Registry...");

  try {
    // Deploy OperatorFilterRegistry
    const OperatorFilterRegistry = await ethers.getContractFactory("OperatorFilterRegistry");
    const registry = await OperatorFilterRegistry.deploy();
    await registry.waitForDeployment();
    const registryAddress = await registry.getAddress();
    console.log("OperatorFilterRegistry deployed to:", registryAddress);
    
    console.log("Operator Filter deployment completed successfully!");
    
    return { operatorFilterRegistry: registryAddress };
  } catch (error) {
    console.error("Error deploying Operator Filter Registry:", error);
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
EOF

# Tạo script để biên dịch và deploy tất cả
echo "[8/8] Tạo script để biên dịch và deploy tất cả components..."
cat > "${WORKSPACE_ROOT}/components/build-and-deploy-all.sh" << 'EOF'
#!/bin/bash
set -e

COMPONENTS_DIR=$(pwd)
COMPONENTS=("seaport" "erc721" "erc1155" "operator-filter")

echo "===== Building and deploying all OpenSea QC components ====="

for component in "${COMPONENTS[@]}"; do
  echo ""
  echo "===== Processing $component component ====="
  cd "$COMPONENTS_DIR/$component"
  
  echo "Installing dependencies..."
  yarn install
  
  echo "Compiling contracts..."
  yarn compile
  
  echo "Running deployment script..."
  yarn deploy
  
  echo "$component processing completed!"
done

echo ""
echo "===== All components have been processed successfully! ====="
EOF

chmod +x "${WORKSPACE_ROOT}/components/build-and-deploy-all.sh"

# Khởi tạo các git repositories cho mỗi component
for component in seaport erc721 erc1155 operator-filter; do
  cd "${COMPONENTS_DIR}/${component}"
  git init > /dev/null 2>&1 || echo "Không thể khởi tạo git repo cho $component"
  echo "node_modules" > .gitignore
  echo "cache" >> .gitignore
  echo "artifacts" >> .gitignore
  git add . > /dev/null 2>&1 || echo "Không thể git add cho $component"
  git commit -m "Initial commit for ${component} component" > /dev/null 2>&1 || echo "Không thể git commit cho $component"
done

# Cleanup
if [ -d "${WORKSPACE_ROOT}/temp-seaport" ]; then
  rm -rf "${WORKSPACE_ROOT}/temp-seaport"
fi

echo ""
echo "===== Quá trình tách dự án hoàn tất! ====="
echo "Các components đã được tạo tại: ${COMPONENTS_DIR}"
echo ""
echo "Để biên dịch và deploy tất cả các components, chạy:"
echo "cd ${COMPONENTS_DIR} && ./build-and-deploy-all.sh"
echo ""
echo "Để làm việc với từng component riêng biệt:"
echo "cd ${COMPONENTS_DIR}/seaport    # Cho Seaport"
echo "cd ${COMPONENTS_DIR}/erc721     # Cho ERC721"
echo "cd ${COMPONENTS_DIR}/erc1155    # Cho ERC1155"
echo "cd ${COMPONENTS_DIR}/operator-filter # Cho Operator Filter"
echo ""
echo "Mỗi component có thể được biên dịch riêng bằng cách chạy 'yarn compile'"
echo "và được deploy riêng bằng cách chạy 'yarn deploy'"