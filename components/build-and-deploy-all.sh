#!/bin/bash
set -e

COMPONENTS_DIR=~/opensea-qc/components
COMPONENTS=("seaport" "erc721" "erc1155" "operator-filter")

echo "===== Building and deploying all OpenSea QC components ====="

# Xử lý Seaport đặc biệt (sử dụng lệnh build thay vì compile)
echo ""
echo "===== Processing Seaport component ====="
cd "$COMPONENTS_DIR/seaport"

echo "Installing dependencies..."
yarn install

echo "Building Seaport contracts..."
yarn build  # Sử dụng lệnh build thay vì compile cho Seaport

echo "Running Seaport tests to verify..."
yarn test

echo "Seaport processing completed!"

# Xử lý các component còn lại
for component in "erc721" "erc1155" "operator-filter"; do
  echo ""
  echo "===== Processing $component component ====="
  cd "$COMPONENTS_DIR/$component"
  
  echo "Installing dependencies..."
  yarn install
  
  echo "Compiling contracts..."
  if yarn run | grep -q "compile"; then
    yarn compile
  else
    echo "No compile script found, trying build..."
    yarn build || echo "No build script found, skipping compilation"
  fi
  
  echo "Running deployment script..."
  if yarn run | grep -q "deploy"; then
    yarn deploy
  else
    echo "No deploy script found, skipping deployment"
  fi
  
  echo "$component processing completed!"
done

echo ""
echo "===== All components have been processed successfully! ====="