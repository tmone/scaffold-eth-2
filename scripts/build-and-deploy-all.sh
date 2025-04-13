#!/bin/bash

# Build and Deploy All Components Script for OpenSea QC Marketplace
# This script compiles and deploys all the components of the project

set -e # Exit immediately if a command exits with a non-zero status

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================================${NC}"
echo -e "${BLUE}         OpenSea QC Marketplace - Build & Deploy         ${NC}"
echo -e "${BLUE}=========================================================${NC}"

# Root directory of the project
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Ensure the script is run from the project root
cd "$ROOT_DIR"

# Function to display a header for each section
function section_header() {
    echo -e "\n${YELLOW}>>> $1${NC}"
}

# Function to run a command with error handling
function run_command() {
    echo -e "${GREEN}$ $1${NC}"
    eval "$1" || { echo -e "${RED}Command failed: $1${NC}"; exit 1; }
}

# Check required commands
section_header "Checking required tools"
for cmd in node yarn docker; do
    if command -v $cmd >/dev/null 2>&1; then
        echo -e "${GREEN}✓ $cmd is installed${NC}"
    else
        echo -e "${RED}✗ $cmd is required but not installed${NC}"
        exit 1
    fi
done

# Set up Docker services
section_header "Starting Docker services"
run_command "cd docker && docker-compose up -d"
echo "Waiting for services to start..."
sleep 10

# Build and test Seaport
section_header "Building Seaport Protocol"
run_command "cd components/seaport && yarn install && yarn build"
echo "Running Seaport tests..."
run_command "cd components/seaport && yarn test"

# Build ERC721 components
section_header "Building ERC721 Components"
run_command "cd components/erc721 && yarn install && yarn build"

# Build ERC1155 components
section_header "Building ERC1155 Components"
run_command "cd components/erc1155 && yarn install && yarn build"

# Build Operator Filter Registry
section_header "Building Operator Filter Registry"
run_command "cd components/operator-filter && yarn install && yarn build"

# Build and deploy Scaffold-ETH 2
section_header "Building Scaffold-ETH 2"
run_command "cd packages/hardhat && yarn install"
run_command "cd packages/nextjs && yarn install"

# Compile and deploy smart contracts
section_header "Compiling and deploying smart contracts"
run_command "cd packages/hardhat && yarn deploy"

# Run tests
section_header "Running tests"
run_command "cd packages/hardhat && yarn test"

# Start frontend development server
section_header "Starting frontend development server"
run_command "cd packages/nextjs && yarn dev &"
echo "Frontend server starting at http://localhost:3000"

echo -e "\n${BLUE}=========================================================${NC}"
echo -e "${GREEN}Build and deployment completed successfully!${NC}"
echo -e "${BLUE}=========================================================${NC}"
echo -e "You can access the application at: http://localhost:3000"
echo -e "To stop all services, run: cd docker && docker-compose down"
echo -e "${BLUE}=========================================================${NC}"