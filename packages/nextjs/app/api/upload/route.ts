import { NextResponse } from 'next/server';
import { generateMockIpfsCid } from '~~/utils/ipfs-helpers';
import fs from 'fs';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';

// Maximum file size (10MB)
const MAX_FILE_SIZE = 10 * 1024 * 1024; 

export async function POST(request: Request) {
  try {
    console.log("📤 File upload API called");
    
    // Process form data
    const formData = await request.formData();
    const file = formData.get('file') as File;
    
    if (!file) {
      console.error("❌ No file provided in upload request");
      return NextResponse.json(
        { success: false, error: "No file provided" },
        { status: 400 }
      );
    }
    
    // Validate file size
    if (file.size > MAX_FILE_SIZE) {
      console.error(`❌ File size (${file.size} bytes) exceeds the limit of ${MAX_FILE_SIZE} bytes`);
      return NextResponse.json(
        { success: false, error: "File size exceeds 10MB limit" },
        { status: 400 }
      );
    }
    
    // Validate file type
    if (!file.type.startsWith('image/')) {
      console.error(`❌ Invalid file type: ${file.type}`);
      return NextResponse.json(
        { success: false, error: "Only image files are allowed" },
        { status: 400 }
      );
    }
    
    // Generate a unique filename
    const fileExtension = file.name.split('.').pop();
    const fileName = `${uuidv4()}.${fileExtension}`;
    const uploadsDir = path.join(process.cwd(), 'public', 'uploads');
    
    // Ensure the uploads directory exists
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
    }

    // Save the file to local storage
    const fileBuffer = await file.arrayBuffer();
    const filePath = path.join(uploadsDir, fileName);
    fs.writeFileSync(filePath, Buffer.from(fileBuffer));
    
    // Instead of using public IPFS gateway, use our local image server
    const localUrl = `/uploads/${fileName}`;
    const fileUrl = `http://localhost:3001${localUrl}`;
    const mockCid = generateMockIpfsCid(); // Keep this for compatibility with existing code
    
    // Log successful upload
    console.log("✅ File upload successful - storing in local image server");
    console.log(`File saved to: ${filePath}`);
    console.log(`Local URL: ${localUrl}`);
    console.log(`File URL: ${fileUrl}`);
    
    return NextResponse.json({
      success: true,
      url: `ipfs://${mockCid}`, // Keep IPFS format for compatibility
      cid: mockCid,
      type: 'localipfs',
      gatewayUrl: fileUrl, // Use the local URL for display
      publicUrl: fileUrl,
      localPath: localUrl,
    });
    
  } catch (error: any) {
    console.error("❌ File upload failed:", error);
    return NextResponse.json(
      { 
        success: false, 
        error: error.message || "File upload failed", 
        stack: process.env.NODE_ENV === 'development' ? error.stack : undefined 
      },
      { status: 500 }
    );
  }
}