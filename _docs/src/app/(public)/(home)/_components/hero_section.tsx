import { BookOpen, Download, ExternalLink } from "lucide-react";
import { baseOptions } from "@/lib/layout.shared";
import { latestVersion, storeUrl } from "@/lib/shared";

export interface IHeroSectionProps {}

export function HeroSection(props: IHeroSectionProps) {
  const { githubUrl } = baseOptions();
  return (
    <section className="w-full max-w-6xl mx-auto px-4 sm:px-6 pt-20 pb-16 flex flex-col items-center text-center">
      {/* Version Pill */}
      <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[#201f1f] border border-[#3b4b37]/50 text-xs font-mono text-[#b9ccb2] mb-8 light:bg-slate-100 light:border-slate-300 light:text-slate-600">
        <span className="w-2 h-2 rounded-full bg-[#00ff41]" />
        <span className="tracking-wider font-semibold">
          {latestVersion.label}
        </span>
      </div>

      {/* Hero Title */}
      <h1 className="font-display font-bold text-3xl sm:text-5xl lg:text-6xl text-white light:text-slate-900 max-w-4xl tracking-tight leading-[1.1] mb-6">
        The High-Performance In-Game Console for Godot
      </h1>

      {/* Hero Subtitle */}
      <p className="font-mono text-sm sm:text-base text-[#b9ccb2] light:text-slate-600 max-w-2xl mx-auto mb-10 leading-relaxed">
        Full-featured, extensible in-game developer console for Godot 4.
        Complete with syntax-highlighted input, variable store, batch
        automation, and async gameplay command pipelines.
      </p>

      {/* Action Buttons */}
      <div className="flex flex-wrap items-center justify-center gap-4 mb-10">
        <a
          href={storeUrl}
          target="_blank"
          rel="noopener noreferrer"
          className="px-6 py-3 rounded text-xs font-mono font-bold tracking-wider bg-[#00ff41] hover:brightness-110 text-[#003907] transition-all shadow-lg shadow-[#00ff41]/20 inline-flex items-center gap-2 cursor-pointer"
        >
          <Download className="w-4 h-4" />
          <span>[ GET ADDON ]</span>
        </a>

        <a
          href={"/docs/getting_started"}
          target="_blank"
          rel="noopener noreferrer"
          className="px-6 py-3 rounded text-xs font-mono font-bold tracking-wider bg-[#201f1f] hover:bg-[#2a2a2a] text-white border border-[#353534] light:bg-white light:hover:bg-slate-100 light:border-slate-300 light:text-slate-900 transition-colors inline-flex items-center gap-2 cursor-pointer"
        >
          <BookOpen className="w-4 h-4 text-[#00ff41]" />
          <span>READ DOCUMENTATION</span>
        </a>
      </div>

      {/* Get Addon Command Box */}
      <div className="w-full max-w-xl p-3 sm:px-4 sm:py-3 rounded bg-[#1c1b1b] border border-[#2a2a2a] light:bg-white light:border-slate-200 shadow-xl flex items-center justify-between gap-3">
        <div className="grid items-center gap-2 min-w-0 font-mono text-xs sm:text-sm">
          <div className="flex items-center gap-1.5 shrink-0">
            <span className="text-[#00ff41] font-bold">&gt;</span>
            <span className="text-white light:text-slate-800 truncate">
              Copy{" "}
              <code className="text-[#00ff41] bg-[#00ff41]/10 px-1 py-0.5 rounded">
                dckit/
              </code>{" "}
              into{" "}
              <code className="text-[#00e5ff] bg-[#00e5ff]/10 px-1 py-0.5 rounded">
                addons/
              </code>{" "}
              folder
            </span>
          </div>
          <div className="flex items-center gap-1.5 shrink-0">
            <span className="text-[#00ff41] font-bold">&gt;</span>
            enable plugin from <b>Project Settings</b>
          </div>
        </div>
        <div className="flex items-center gap-1.5 shrink-0">
          <a
            href={githubUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="p-1 rounded text-neutral-400 hover:text-[#00ff41] transition-colors"
            title="View on Godot Asset Library / GitHub"
          >
            <ExternalLink className="w-4 h-4" />
          </a>
        </div>
      </div>
    </section>
  );
}
