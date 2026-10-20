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
  // metadataBase: new URL(siteUrl),

  title: {
    default: "DCKit — Godot Addons & In-game Console",
    template: "%s | DCKit",
  },

  description:
    "Explore DCKit, In-Game console for Godot with simple way to define custom command.",

  applicationName: "DCKit",

  openGraph: {
    type: "website",
    siteName: "DCKit",
    title: "DCKit — Godot Addons & In-game Console",
    description:
      "Explore DCKit, a Godot in-game console for easily defining custom commands.",
    url: siteUrl,
    images: [
      {
        url: "/og_img.jpg",
        width: 1440,
        height: 810,
        alt: "DCKit — Godot Addons & In-game Console",
      },
    ],
  },

  twitter: {
    card: "summary_large_image",
    title: "DCKit — Godot Addons & In-game Console",
    description:
      "Explore DCKit, a Godot in-game console for easily defining custom commands.",
    images: ["/og_img.jpg"],
  },

  robots: {
    index: true,
    follow: true,
  },
};
