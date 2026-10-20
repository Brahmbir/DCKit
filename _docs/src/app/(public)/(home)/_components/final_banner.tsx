import { Download, BookOpen } from "lucide-react";
import Link from "next/link";
import { latestVersion, storeUrl } from "@/lib/shared";

type Props = {};

export default function FinalBanner({}: Props) {
  const storeLink = storeUrl ?? "/";

  return (
    <section className="w-full max-w-5xl mx-auto px-4 sm:px-6 py-16">
      <div className="rounded-xl bg-fd-card/80 backdrop-blur-xl border border-fd-border p-8 sm:p-12 text-center flex flex-col items-center shadow-xl">
        <span className="font-mono text-xs font-bold text-fd-primary tracking-widest mb-3">
          GODOT 4 ASSET LIBRARY
        </span>

        <h2 className="font-display font-bold text-2xl sm:text-4xl text-fd-foreground max-w-xl mb-4">
          Your game’s debugging toolkit, ready when you are.
        </h2>

        <p className="font-mono text-xs sm:text-sm text-fd-muted-foreground max-w-lg mb-8 leading-relaxed">
          Bring powerful in-game tools to your Godot 4 projects with DCKit.
          Explore the addon, customize your debugging setup, and integrate the
          tools you need to build and debug with confidence.
        </p>

        <div className="flex flex-wrap items-center justify-center gap-4">
          <Link
            href={storeLink}
            target="_blank"
            rel="noopener noreferrer"
            className="px-6 py-3 rounded text-xs font-mono font-bold tracking-wider bg-fd-primary hover:brightness-110 text-fd-primary-foreground transition-all shadow-lg inline-flex items-center gap-2 cursor-pointer"
          >
            <Download className="w-4 h-4" />
            <span>GET ADDON ON GODOT STORE</span>
          </Link>

          <Link
            href={"/docs" + latestVersion.url}
            target="_blank"
            className="px-6 py-3 rounded text-xs font-mono font-bold tracking-wider bg-fd-muted hover:bg-fd-accent text-fd-foreground border border-fd-border transition-colors inline-flex items-center gap-2 cursor-pointer"
          >
            <BookOpen className="w-4 h-4 text-fd-primary" />
            <span>EXPLORE GUIDES</span>
          </Link>
        </div>
      </div>
    </section>
  );
}
