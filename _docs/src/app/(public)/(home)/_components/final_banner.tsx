import { Download, BookOpen } from "lucide-react";
import Link from "next/link";
import { storeUrl } from "@/lib/shared";

type Props = {};

export default function FinalBanner({}: Props) {
  const storeLink = storeUrl ?? "/";

  return (
    <section className="w-full max-w-5xl mx-auto px-4 sm:px-6 py-16">
      <div className="rounded-xl bg-[#2a2a2a]/40 backdrop-blur-xl border border-[#353534] light:bg-slate-100 light:border-slate-200 p-8 sm:p-12 text-center flex flex-col items-center shadow-xl">
        <span className="font-mono text-xs font-bold text-[#00ff41] tracking-widest mb-3">
          GODOT 4 ASSET LIBRARY
        </span>
        <h2 className="font-display font-bold text-2xl sm:text-4xl text-white light:text-slate-900 max-w-xl mb-4">
          Your game’s debugging toolkit, ready when you are.
        </h2>
        <p className="font-mono text-xs sm:text-sm text-[#b9ccb2] light:text-slate-600 max-w-lg mb-8 leading-relaxed">
          Bring powerful in-game tools to your Godot 4 projects with DCKit.
          Explore the addon, customize your debugging setup, and integrate the
          tools you need to build and debug with confidence.
        </p>
        <div className="flex flex-wrap items-center justify-center gap-4">
          <Link
            href={storeLink}
            target="_blank"
            rel="noopener noreferrer"
            className="px-6 py-3 rounded text-xs font-mono font-bold tracking-wider bg-[#00ff41] hover:brightness-110 text-[#003907] transition-all shadow-lg shadow-[#00ff41]/20 inline-flex items-center gap-2 cursor-pointer"
          >
            <Download className="w-4 h-4" />
            <span>GET ADDON ON GODOT STORE</span>
          </Link>
          <Link
            href="/docs/quickstart"
            className="px-6 py-3 rounded text-xs font-mono font-bold tracking-wider bg-[#201f1f] hover:bg-[#2a2a2a] text-white border border-[#353534] light:bg-white light:hover:bg-slate-200 light:border-slate-300 light:text-slate-900 transition-colors inline-flex items-center gap-2 cursor-pointer"
          >
            <BookOpen className="w-4 h-4 text-[#00ff41]" />
            <span>EXPLORE GUIDES</span>
          </Link>
        </div>
      </div>
    </section>
  );
}
