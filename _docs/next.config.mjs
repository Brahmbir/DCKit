import { createMDX } from "fumadocs-mdx/next";

const withMDX = createMDX();

const basePath = "/DCKit";

/** @type {import('next').NextConfig} */
const config = {
  basePath,
  env: { NEXT_PUBLIC_BASE_PATH: basePath },
  images: { unoptimized: true },
  output: "export",
  reactStrictMode: true,
};

export default withMDX(config);
