#!/bin/bash

# Đường dẫn đến thư mục gốc của dự án
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)

# Đảm bảo thư mục logs tồn tại
mkdir -p "$PROJECT_ROOT/scripts/logs"

echo "===== Khởi động các dịch vụ lưu trữ cho OpenSea QC ====="

# Kiểm tra xem Docker đã chạy chưa
if ! docker info > /dev/null 2>&1; then
    echo "Docker không chạy. Vui lòng khởi động Docker trước."
    exit 1
fi

# Khởi động các dịch vụ Docker
echo "Khởi động các container Docker cho lưu trữ..."
cd "$PROJECT_ROOT/docker" && docker-compose up -d ipfs image-server

# Đợi các dịch vụ khởi động
echo "Đang đợi các dịch vụ khởi động..."
sleep 5

# Tạo các thư mục cần thiết trong Next.js public và đảm bảo quyền ghi đúng
echo "Tạo các thư mục lưu trữ trong Next.js với quyền ghi đầy đủ..."
mkdir -p "$PROJECT_ROOT/packages/nextjs/public/uploads"
mkdir -p "$PROJECT_ROOT/packages/nextjs/public/metadata"
mkdir -p "$PROJECT_ROOT/packages/nextjs/public/images"

# Fix quyền truy cập để Node.js có thể ghi vào các thư mục này
chmod -R 777 "$PROJECT_ROOT/packages/nextjs/public/uploads"
chmod -R 777 "$PROJECT_ROOT/packages/nextjs/public/metadata"
chmod -R 777 "$PROJECT_ROOT/packages/nextjs/public/images"

echo "Đã thiết lập quyền truy cập cho các thư mục upload"

# Kiểm tra trạng thái của các dịch vụ
echo "Kiểm tra trạng thái các dịch vụ lưu trữ:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep opensea

echo ""
echo "===== Hệ thống lưu trữ đã sẵn sàng ====="
echo "IPFS API: http://localhost:5001/api/v0"
echo "IPFS Gateway: http://localhost:8080/ipfs"
echo "Image Server: http://localhost:3001"
echo ""
echo "Bạn có thể bắt đầu ứng dụng Next.js:"
echo "cd $PROJECT_ROOT/packages/nextjs && npm run dev"