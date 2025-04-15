import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  devIndicators: false,
  typescript: {
    ignoreBuildErrors: process.env.NEXT_PUBLIC_IGNORE_BUILD_ERROR === "true",
  },
  eslint: {
    ignoreDuringBuilds: process.env.NEXT_PUBLIC_IGNORE_BUILD_ERROR === "true",
  },
  // Environment variables that need to be accessible in the browser
  env: {
    NEXT_PUBLIC_DISABLE_ENS: process.env.NEXT_PUBLIC_DISABLE_ENS || "false",
    NEXT_PUBLIC_USE_BURNER_WALLET: process.env.NEXT_PUBLIC_USE_BURNER_WALLET || "true",
    NEXT_PUBLIC_LOCAL_RPC_URL: process.env.NEXT_PUBLIC_LOCAL_RPC_URL || "http://localhost:8545",
  },
  // Enhanced hot reloading and file watching config
  webpack: config => {
    config.resolve.fallback = { fs: false, net: false, tls: false };
    config.externals.push("pino-pretty", "lokijs", "encoding");
    
    // Custom file watching options
    config.watchOptions = {
      aggregateTimeout: 300,
      poll: 1000, // Check for changes every second
      ignored: ['**/node_modules', '**/.git', '**/dist', '**/build'],
    };
    
    // Optimize chunk loading to fix ChunkLoadError
    if (config.optimization && config.optimization.splitChunks) {
      config.optimization.splitChunks = {
        ...config.optimization.splitChunks,
        cacheGroups: {
          ...(config.optimization.splitChunks as any).cacheGroups,
          default: false,
          vendors: false,
          framework: {
            name: 'framework',
            test: /[\\/]node_modules[\\/](react|react-dom|scheduler|next|@rainbow-me|wagmi)[\\/]/,
            priority: 40,
            enforce: true,
            chunks: 'all',
          },
          lib: {
            test: /[\\/]node_modules[\\/]/,
            priority: 30,
            chunks: 'all',
            name(module: any) {
              const match = module.context.match(/[\\/]node_modules[\\/](.*?)([\\/]|$)/);
              if (!match) return 'lib';
              const packageName = match[1];
              return `lib-${packageName.replace('@', '')}`;
            }
          },
        },
      };
    }
    
    return config;
  },
  // Configure onDemandEntries for faster refresh rates
  onDemandEntries: {
    // period (in ms) where the server will keep pages in the buffer
    maxInactiveAge: 25 * 1000,
    // number of pages that should be kept simultaneously without being disposed
    pagesBufferLength: 5,
  },
};

const isIpfs = process.env.NEXT_PUBLIC_IPFS_BUILD === "true";

if (isIpfs) {
  nextConfig.output = "export";
  nextConfig.trailingSlash = true;
  nextConfig.images = {
    unoptimized: true,
  };
}

module.exports = nextConfig;
