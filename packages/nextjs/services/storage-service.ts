/**
 * Storage service để xử lý hình ảnh và metadata cho NFT
 * Sử dụng IPFS node trong Docker container
 */
import axios from 'axios';
import FormData from 'form-data';
import fs from 'fs';
import path from 'path';

// IPFS Node API endpoint từ Docker container
const IPFS_API_URL = process.env.NEXT_PUBLIC_IPFS_API_URL || 'http://localhost:5001/api/v0';
// URL để truy cập IPFS gateway nội bộ
const IPFS_GATEWAY_URL = process.env.NEXT_PUBLIC_IPFS_GATEWAY_URL || 'http://localhost:8080/ipfs';

/**
 * Upload file lên IPFS node nội bộ
 */
export const uploadToIPFS = async (file: File): Promise<string> => {
  try {
    // Tạo FormData để gửi file
    const formData = new FormData();
    const buffer = await file.arrayBuffer();
    formData.append('file', Buffer.from(buffer), {
      filename: file.name,
      contentType: file.type,
    });

    // Gọi API để add file vào IPFS node
    const response = await axios.post(`${IPFS_API_URL}/add`, formData, {
      headers: {
        ...formData.getHeaders(),
      },
    });

    // Trả về CID của file
    const { Hash } = response.data;
    return Hash;
  } catch (error) {
    console.error('Error uploading to IPFS:', error);
    
    // Nếu gặp lỗi khi upload lên IPFS, lưu file vào thư mục public/images
    // và trả về đường dẫn tới file đó
    const buffer = await file.arrayBuffer();
    const fileName = `${Date.now()}_${file.name}`;
    const filePath = path.join(process.cwd(), 'public', 'images', fileName);
    
    // Đảm bảo thư mục tồn tại
    const dir = path.join(process.cwd(), 'public', 'images');
    if (!fs.existsSync(dir)){
        fs.mkdirSync(dir, { recursive: true });
    }
    
    // Ghi file
    fs.writeFileSync(filePath, Buffer.from(buffer));
    
    // Trả về đường dẫn local thay vì IPFS hash
    return `local:${fileName}`;
  }
};

/**
 * Tạo URI cho một hình ảnh đã upload
 * Hỗ trợ cả IPFS hash và local file
 */
export const getImageUri = (hash: string): string => {
  if (hash.startsWith('local:')) {
    const fileName = hash.substring(6);
    return `/images/${fileName}`;
  }
  return `ipfs://${hash}`;
};

/**
 * Tạo URL hiển thị cho hình ảnh
 * Chuyển đổi từ ipfs:// hoặc local: sang URL có thể truy cập được
 */
export const getImageUrl = (uri: string): string => {
  if (!uri) return '';
  
  if (uri.startsWith('ipfs://')) {
    const hash = uri.substring(7);
    return `${IPFS_GATEWAY_URL}/${hash}`;
  }
  
  if (uri.startsWith('local:')) {
    const fileName = uri.substring(6);
    return `/images/${fileName}`;
  }
  
  // Trả về URI gốc nếu không phải ipfs:// hoặc local:
  return uri;
};

/**
 * Upload metadata lên IPFS
 */
export const uploadMetadataToIPFS = async (metadata: any): Promise<string> => {
  try {
    // Tạo file JSON từ metadata
    const metadataStr = JSON.stringify(metadata);
    const blob = new Blob([metadataStr], { type: 'application/json' });
    const file = new File([blob], 'metadata.json', { type: 'application/json' });
    
    // Upload lên IPFS
    const hash = await uploadToIPFS(file);
    return hash;
  } catch (error) {
    console.error('Error uploading metadata to IPFS:', error);
    
    // Nếu gặp lỗi khi upload lên IPFS, lưu metadata vào thư mục public/metadata
    const fileName = `metadata_${Date.now()}.json`;
    const filePath = path.join(process.cwd(), 'public', 'metadata', fileName);
    
    // Đảm bảo thư mục tồn tại
    const dir = path.join(process.cwd(), 'public', 'metadata');
    if (!fs.existsSync(dir)){
        fs.mkdirSync(dir, { recursive: true });
    }
    
    // Ghi file
    fs.writeFileSync(filePath, JSON.stringify(metadata, null, 2));
    
    // Trả về đường dẫn local thay vì IPFS hash
    return `local:${fileName}`;
  }
};

/**
 * Tạo URI cho metadata đã upload
 */
export const getMetadataUri = (hash: string): string => {
  if (hash.startsWith('local:')) {
    const fileName = hash.substring(6);
    return `/metadata/${fileName}`;
  }
  return `ipfs://${hash}`;
};

/**
 * Tạo URL hiển thị cho metadata
 */
export const getMetadataUrl = (uri: string): string => {
  if (!uri) return '';
  
  if (uri.startsWith('ipfs://')) {
    const hash = uri.substring(7);
    return `${IPFS_GATEWAY_URL}/${hash}`;
  }
  
  if (uri.startsWith('local:')) {
    const fileName = uri.substring(6);
    return `/metadata/${fileName}`;
  }
  
  return uri;
};