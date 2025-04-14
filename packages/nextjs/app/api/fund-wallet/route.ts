import { NextRequest, NextResponse } from "next/server";
import { exec } from "child_process";
import { promisify } from "util";
import path from "path";

const execAsync = promisify(exec);

export async function POST(request: NextRequest) {
  try {
    // Parse the wallet address from the request body
    const { walletAddress } = await request.json();
    
    if (!walletAddress || typeof walletAddress !== "string") {
      return NextResponse.json(
        { success: false, error: "Valid wallet address required" },
        { status: 400 }
      );
    }
    
    // Path to the hardhat package
    const hardhatDir = path.resolve(process.cwd(), "../hardhat");
    
    // Execute the fund-wallet script
    const { stdout, stderr } = await execAsync(
      `cd ${hardhatDir} && npx hardhat run scripts/fund-wallet.ts --network localhost "${walletAddress}"`
    );
    
    if (stderr) {
      console.error("Error funding wallet:", stderr);
      return NextResponse.json(
        { success: false, error: stderr },
        { status: 500 }
      );
    }
    
    console.log("Funding result:", stdout);
    
    return NextResponse.json({
      success: true,
      message: "Wallet funded with 100 ETH",
      output: stdout
    });
  } catch (error) {
    console.error("Failed to fund wallet:", error);
    return NextResponse.json(
      { success: false, error: "Failed to fund wallet" },
      { status: 500 }
    );
  }
}

export async function GET() {
  return NextResponse.json(
    { success: false, error: "Use POST request with wallet address" },
    { status: 405 }
  );
}