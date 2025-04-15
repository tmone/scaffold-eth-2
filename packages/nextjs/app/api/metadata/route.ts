import { NextRequest, NextResponse } from 'next/server';
import * as fs from 'fs';
import * as path from 'path';
import { v4 as uuidv4 } from 'uuid';
import axios from 'axios';
import { generateMockIpfsCid } from '~~/utils/ipfs-helpers';

interface NFTMetadata {
  name: string;
  description: string;
  image: string;
  attributes: Array<{
    trait_type: string;
    value: string | number;
  }>;
}

// IPFS Node API endpoint từ Docker container
const IPFS_API_URL = process.env.NEXT_PUBLIC_IPFS_API_URL || 'http://localhost:5001/api/v0';
const LOCAL_IMAGE_SERVER = process.env.NEXT_PUBLIC_IMAGE_SERVER || 'http://localhost:3001';

/**
 * API route để xử lý lưu trữ metadata của NFT
 */
export async function POST(request: Request) {
  try {
    console.log("📝 Metadata API called");
    
    // Parse the JSON body
    const body = await request.json();
    
    // Validate required fields
    if (!body.name) {
      console.error("❌ Missing required field: name");
      return NextResponse.json(
        { success: false, error: "Name is required" },
        { status: 400 }
      );
    }
    
    if (!body.image) {
      console.error("❌ Missing required field: image");
      return NextResponse.json(
        { success: false, error: "Image URL is required" },
        { status: 400 }
      );
    }
    
    // Create metadata object
    const metadata: NFTMetadata = {
      name: body.name,
      description: body.description || "",
      image: body.image,
      attributes: body.attributes || []
    };
    
    // Generate a UUID for the metadata file
    const metadataId = uuidv4();
    const fileName = `${metadataId}.json`;
    const metadataDir = path.join(process.cwd(), 'public', 'metadata');
    
    // Ensure the metadata directory exists
    if (!fs.existsSync(metadataDir)) {
      fs.mkdirSync(metadataDir, { recursive: true });
    }
    
    // Save metadata to local file system
    const filePath = path.join(metadataDir, fileName);
    fs.writeFileSync(filePath, JSON.stringify(metadata, null, 2));
    
    // Generate local URLs
    const localUrl = `/metadata/${fileName}`;
    const fileUrl = `${LOCAL_IMAGE_SERVER}${localUrl}`;
    
    // Keep compatibility with existing code by generating a mock CID
    const mockCid = generateMockIpfsCid();
    const ipfsUrl = `ipfs://${mockCid}`;
    
    // Log the result
    console.log("✅ Metadata creation successful - storing in local server");
    console.log(`Metadata saved to: ${filePath}`);
    console.log(`Local URL: ${localUrl}`);
    console.log(`File URL: ${fileUrl}`);
    console.log("Metadata:", metadata);
    
    return NextResponse.json({
      success: true,
      url: ipfsUrl, // Keep IPFS format for compatibility
      cid: mockCid,
      localId: metadataId,
      gatewayUrl: fileUrl, // Use local URL for display
      publicUrl: fileUrl,
      localPath: localUrl,
      metadata
    });
    
  } catch (error: any) {
    console.error("❌ Metadata creation failed:", error);
    
    // Enhanced error logging for debugging
    if (error instanceof SyntaxError && error.message.includes('JSON')) {
      console.error("Invalid JSON format in request body");
    }
    
    return NextResponse.json(
      { 
        success: false, 
        error: error.message || "Metadata creation failed",
        stack: process.env.NODE_ENV === 'development' ? error.stack : undefined 
      },
      { status: 500 }
    );
  }
}

/**
 * API route để lấy metadata của NFT
 */
export async function GET(request: NextRequest) {
  const url = new URL(request.url);
  const type = url.searchParams.get('type');
  const id = url.searchParams.get('id');
  
  if (!type || !id) {
    return NextResponse.json({ error: 'Missing type or id parameters' }, { status: 400 });
  }
  
  try {
    if (type === 'ipfs') {
      // Try to get from local IPFS node first
      try {
        const response = await axios.get(`http://localhost:8080/ipfs/${id}`);
        return NextResponse.json(response.data);
      } catch (ipfsError) {
        console.warn("Failed to fetch from local IPFS, metadata may not exist locally:", ipfsError.message);
        // Fall back to public gateway as a last resort
        try {
          const response = await axios.get(`https://ipfs.io/ipfs/${id}`);
          return NextResponse.json(response.data);
        } catch (publicError) {
          console.error("Failed to fetch from public IPFS gateway:", publicError.message);
          return NextResponse.json({ error: 'Metadata not found on IPFS' }, { status: 404 });
        }
      }
    } else if (type === 'local') {
      // Get metadata from local file
      const filePath = path.join(process.cwd(), 'public', 'metadata', `${id}.json`);
      if (!fs.existsSync(filePath)) {
        return NextResponse.json({ error: 'Metadata not found' }, { status: 404 });
      }
      
      const metadata = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
      return NextResponse.json(metadata);
    } else {
      return NextResponse.json({ error: 'Invalid type parameter' }, { status: 400 });
    }
  } catch (error: any) {
    console.error('Error fetching metadata:', error);
    return NextResponse.json({ 
      error: 'Failed to fetch metadata',
      message: error.message 
    }, { status: 500 });
  }
}