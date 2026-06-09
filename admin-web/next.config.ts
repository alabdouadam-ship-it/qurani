import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Static HTML export — Firebase Hosting serves plain files (no Node server).
  // Safe here: the admin app is a client-only SPA that talks to Supabase from
  // the browser; there are no API routes, middleware, or server components
  // requiring a runtime.
  output: "export",
  // next/image optimization needs a server; disable it for static export.
  images: { unoptimized: true },
  // Emit /login/index.html etc. so Firebase serves clean URLs without config.
  trailingSlash: true,
};

export default nextConfig;
