/** @type {import('next').NextConfig} */
const nextConfig = {};

module.exports = nextConfig;

module.exports = {
    images: {
      remotePatterns: [
        {
          protocol: 'https',
          hostname: 'mediolano.com.br',
          port: '',
          pathname: '/wp-content/uploads/2024/01/**',
        },
      ],
    },
  }