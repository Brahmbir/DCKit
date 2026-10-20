import { BookOpen, Download, ExternalLink } from "lucide-react";
import { baseOptions } from "@/lib/layout.shared";
import { latestVersion, storeUrl } from "@/lib/shared";

export interface IHeroSectionProps {}

export function HeroSection(props: IHeroSectionProps) {
  const { githubUrl } = baseOptions();
  return (
    <section className="w-full max-w-6xl mx-auto px-4 sm:px-6 pt-20 pb-16 flex flex-col items-center text-center">
      {/* Version Pill */}
      <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-fd-secondary border border-fd-border text-xs font-mono text-fd-muted-foreground mb-8 light:bg-slate-100 light:border-slate-300 light:text-slate-600">
        <span className="w-2 h-2 rounded-full bg-fd-primary" />
        <span className="tracking-wider font-semibold">
          {latestVersion.label}
        </span>
      </div>

      {/* Hero Title */}
      <h1 className="font-display font-bold text-3xl sm:text-5xl lg:text-6xl text-fd-foreground light:text-slate-900 max-w-4xl tracking-tight leading-[1.1] mb-6">
        The High-Performance In-Game Console for Godot
      </h1>

      {/* Hero Subtitle */}
      <p className="font-mono text-sm sm:text-base text-fd-muted-foreground light:text-slate-600 max-w-2xl mx-auto mb-10 leading-relaxed">
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
          className="px-6 py-3 rounded text-xs font-mono font-bold tracking-wider bg-fd-primary hover:brightness-110 text-fd-primary-foreground transition-all shadow-lg shadow-fd-primary/20 inline-flex items-center gap-2 cursor-pointer"
        >
          <Download className="w-4 h-4" />
          <span>[ GET ADDON ]</span>
        </a>

        <a
          href={"/docs" + latestVersion.url}
          target="_blank"
          rel="noopener noreferrer"
          className="px-6 py-3 rounded text-xs font-mono font-bold tracking-wider bg-fd-secondary hover:bg-fd-muted text-fd-foreground border border-fd-border light:bg-white light:hover:bg-slate-100 light:border-slate-300 light:text-slate-900 transition-colors inline-flex items-center gap-2 cursor-pointer"
        >
          <BookOpen className="w-4 h-4 text-fd-primary" />
          <span>READ DOCUMENTATION</span>
        </a>
      </div>

      {/* Get Addon Command Box */}
      <div className="w-full max-w-xl p-3 sm:px-4 sm:py-3 rounded bg-fd-background border border-fd-border light:bg-white light:border-slate-200 shadow-xl flex items-center justify-between gap-3">
        <div className="grid items-center gap-2 min-w-0 font-mono text-xs sm:text-sm">
          <div className="flex items-center gap-1.5 shrink-0">
            <span className="text-fd-primary font-bold">&gt;</span>
            <span className="text-fd-foreground light:text-slate-800 truncate">
              Copy{" "}
              <code className="text-fd-primary bg-fd-primary/10 px-1 py-0.5 rounded">
                \dckit
              </code>{" "}
              into{" "}
              <code className="text-fd-idea bg-fd-idea/10 px-1 py-0.5 rounded">
                \addons
              </code>{" "}
              folder
            </span>
          </div>
          <div className="flex items-center gap-1.5 shrink-0">
            <span className="text-fd-primary font-bold">&gt;</span>
            enable plugin from <b>Project Settings</b>
          </div>
        </div>
        <div className="flex items-center gap-1.5 shrink-0">
          <a
            href={githubUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="p-1 rounded text-neutral-400 hover:text-fd-primary transition-colors"
            title="View on Godot Asset Library / GitHub"
          >
            <ExternalLink className="w-4 h-4" />
          </a>
        </div>
      </div>
    </section>
  );
}
