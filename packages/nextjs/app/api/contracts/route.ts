import { NextRequest, NextResponse } from "next/server";
import fs from "fs";
import path from "path";

const addressesPath = path.join(process.cwd(), "contracts", "addresses.json");

// Helper function to read addresses
function getAddresses() {
  try {
    const data = fs.readFileSync(addressesPath, "utf8");
    return JSON.parse(data);
  } catch (error) {
    console.error("Error reading addresses file:", error);
    return {
      local: {},
      testnet: {},
      mainnet: {},
    };
  }
}

// Helper function to write addresses
function saveAddresses(addresses: any) {
  try {
    fs.writeFileSync(addressesPath, JSON.stringify(addresses, null, 2));
    return true;
  } catch (error) {
    console.error("Error writing addresses file:", error);
    return false;
  }
}

// GET all contract addresses or specific ones by network/contract name
export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const network = searchParams.get("network");
  const contractName = searchParams.get("contractName");
  
  const addresses = getAddresses();
  
  if (network && contractName) {
    // Return specific contract address
    return NextResponse.json({
      address: addresses[network]?.[contractName] || null
    });
  } else if (network) {
    // Return all contracts for specific network
    return NextResponse.json({
      addresses: addresses[network] || {}
    });
  }
  
  // Return all addresses
  return NextResponse.json({ addresses });
}

// POST to update contract addresses
export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { network, contractName, address } = body;
    
    if (!network || !contractName || !address) {
      return NextResponse.json(
        { error: "Missing required fields: network, contractName, address" },
        { status: 400 }
      );
    }
    
    const addresses = getAddresses();
    
    // Initialize network object if it doesn't exist
    if (!addresses[network]) {
      addresses[network] = {};
    }
    
    // Update the contract address
    addresses[network][contractName] = address;
    
    // Save updated addresses
    if (saveAddresses(addresses)) {
      return NextResponse.json({
        success: true,
        message: `Updated ${contractName} address for ${network}`,
        address
      });
    } else {
      return NextResponse.json(
        { error: "Failed to save contract address" },
        { status: 500 }
      );
    }
  } catch (error) {
    console.error("Error processing contract address update:", error);
    return NextResponse.json(
      { error: "Failed to process request" },
      { status: 500 }
    );
  }
}