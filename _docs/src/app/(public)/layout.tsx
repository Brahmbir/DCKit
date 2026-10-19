import { HomeLayout } from "fumadocs-ui/layouts/home";
import { baseOptions } from "@/lib/layout.shared";

export default function Layout({ children }: LayoutProps<"/">) {
  return (
    <HomeLayout className="HOME_ROOT" {...baseOptions()}>
      {children}
    </HomeLayout>
  );
}

import type { Metadata } from "next";
import { siteUrl } from "@/lib/shared";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),

  title: {
    default: "DCKit — Godot Addons & Developer Tools",
    template: "%s | DCKit",
  },

  description:
    "Explore DCKit, a collection of Godot addons and developer tools designed to simplify workflows and help you build better games with Godot.",

  applicationName: "DCKit",

  openGraph: {
    type: "website",
    siteName: "DCKit",
    title: "DCKit — Godot Addons & Developer Tools",
    description:
      "Discover useful Godot addons, tools, and documentation to streamline your game development workflow.",
    url: siteUrl,
    images: [
      {
        url: "/side_dock_with_logo.png",
        width: 1200,
        height: 630,
        alt: "DCKit — Godot Addons & Developer Tools",
      },
    ],
  },

  twitter: {
    card: "summary_large_image",
    title: "DCKit — Godot Addons & Developer Tools",
    description:
      "Discover Godot addons, developer tools, and documentation to improve your game development workflow.",
    images: ["/side_dock_with_logo.png"],
  },

  robots: {
    index: true,
    follow: true,
  },
};
