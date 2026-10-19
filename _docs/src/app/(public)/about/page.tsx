import { baseOptions } from "@/lib/layout.shared";
import { latestVersion } from "@/lib/shared";
import {
  Terminal,
  ExternalLink,
  Code2,
  Heart,
  Shield,
  Cpu,
  BookOpen,
} from "lucide-react";

export default function AboutPage() {
  return (
    <main className="mx-auto max-w-4xl px-4 sm:px-6 pt-24 pb-20 font-mono">
      {/* Header Badge */}
      <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[#201f1f] border border-[#3b4b37]/60 text-xs text-[#00ff41] mb-6 light:bg-slate-100 light:border-slate-300 light:text-emerald-700">
        <span className="w-2 h-2 rounded-full bg-[#00ff41]" />
        <span>// PROJECT OVERVIEW</span>
      </div>

      {/* Title */}
      <h1 className="font-display font-bold text-3xl sm:text-5xl text-white light:text-slate-900 tracking-tight mb-6">
        About DCKit
      </h1>

      {/* Lead Paragraph */}
      <p className="text-sm sm:text-base text-[#b9ccb2] light:text-slate-600 leading-relaxed mb-12">
        DCKit is an extensible, full-featured in-game developer console built
        from the ground up for Godot 4. Developed and maintained by{" "}
        <a href="https://brahmbir.dev" target="_blank">
          <strong className="text-white light:text-slate-900">Brahmbir</strong>
        </a>
        , it provides developers with a complete command pipeline,
        syntax-highlighted input, autocompletion, reactive variable binding, and
        automated batch scripting directly inside running game sessions.
      </p>

      {/* Grid: Philosophy & Architecture */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-12">
        {/* <div className="p-6 rounded-lg bg-[#1c1b1b] border border-[#2a2a2a] light:bg-white light:border-slate-200">
          <div className="flex items-center gap-2.5 text-[#00ff41] font-bold text-sm mb-3">
            <Cpu className="w-4 h-4" />
            <span>Built For Game Engine Runtimes</span>
          </div>
          <p className="text-xs text-[#b9ccb2] light:text-slate-600 leading-relaxed">
            Unlike generic logging overlays, DCKit is engineered with strict
            per-frame budgets and zero-allocation ring buffers. It ensures
            diagnostic tools never drop frames during intense 60+ or 120+ FPS
            game scenarios.
          </p>
        </div> */}

        <div className="p-6 rounded-lg bg-[#1c1b1b] border border-[#2a2a2a] light:bg-white light:border-slate-200">
          <div className="flex items-center gap-2.5 text-[#00e5ff] font-bold text-sm mb-3">
            <Code2 className="w-4 h-4" />
            <span>GDScript & C# First-Class Parity</span>
          </div>
          <p className="text-xs text-[#b9ccb2] light:text-slate-600 leading-relaxed">
            Whether your project is pure GDScript or uses Godot .NET / C#, DCKit
            provides strongly typed callback bindings, natural lambda delegates,
            and seamless cross-language variable sharing.
          </p>
        </div>

        {/* <div className="p-6 rounded-lg bg-[#1c1b1b] border border-[#2a2a2a] light:bg-white light:border-slate-200">
          <div className="flex items-center gap-2.5 text-[#ffb300] font-bold text-sm mb-3">
            <Terminal className="w-4 h-4" />
            <span>Expressive Simple Syntax</span>
          </div>
          <p className="text-xs text-[#b9ccb2] light:text-slate-600 leading-relaxed">
            The parser supports positional & named arguments, variable
            references (<code className="text-[#00e5ff]">$var</code>), fallbacks
            (<code className="text-[#ffb300]">||</code>), command chaining (
            <code className="text-white">;</code>), and inline comments.
          </p>
        </div> */}

        <div className="p-6 rounded-lg bg-[#1c1b1b] border border-[#2a2a2a] light:bg-white light:border-slate-200">
          <div className="flex items-center gap-2.5 text-[#00ff41] font-bold text-sm mb-3">
            <Shield className="w-4 h-4" />
            <span>Open Source & Community Driven</span>
          </div>
          <p className="text-xs text-[#b9ccb2] light:text-slate-600 leading-relaxed">
            DCKit is completely open-source under the MIT license. Feedback,
            issues, feature requests, and pull requests are welcomed on the
            official GitHub repository.
          </p>
        </div>
      </div>

      {/* Technical Specifications Matrix */}
      <div className="rounded-lg bg-[#1c1b1b] border border-[#2a2a2a] light:bg-white light:border-slate-200 p-6 mb-12">
        <h2 className="font-display font-bold text-xl text-white light:text-slate-900 mb-4">
          Engine Specifications
        </h2>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 text-xs">
          <div>
            <div className="text-neutral-500 light:text-slate-400">
              ENGINE VERSION
            </div>
            <div className="text-white light:text-slate-900 font-semibold mt-1">
              Godot 4.5+
            </div>
          </div>
          <div>
            <div className="text-neutral-500 light:text-slate-400">
              RELEASE STAGE
            </div>
            <div className="text-[#00ff41] font-semibold mt-1">
              {latestVersion.label.toUpperCase()}
            </div>
          </div>
          <div>
            <div className="text-neutral-500 light:text-slate-400">
              LANGUAGES
            </div>
            <div className="text-white light:text-slate-900 font-semibold mt-1">
              GDScript & C#
            </div>
          </div>
          <div>
            <div className="text-neutral-500 light:text-slate-400">LICENSE</div>
            <div className="text-white light:text-slate-900 font-semibold mt-1">
              MIT License
            </div>
          </div>
        </div>
      </div>

      {/* Author & Links */}
      <div className="p-6 rounded-lg bg-[#141414] border border-[#2a2a2a] light:bg-slate-100 light:border-slate-200 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-6">
        <div>
          <div className="text-white light:text-slate-900 font-bold text-sm flex items-center gap-2">
            <span>Created by Brahmbir</span>
            <Heart className="w-3.5 h-3.5 text-red-500 fill-current" />
          </div>
          <p className="text-xs text-[#b9ccb2] light:text-slate-600 mt-1">
            Building game development and runtime diagnostic tooling for Godot
            4.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <a
            href={baseOptions().githubUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="px-4 py-2 rounded text-xs font-mono font-bold bg-[#00ff41] hover:brightness-110 text-[#003907] transition-all inline-flex items-center gap-1.5 cursor-pointer"
          >
            <span>GITHUB REPOSITORY</span>
            <ExternalLink className="w-3.5 h-3.5" />
          </a>
          <a
            href={"/docs"}
            className="px-4 py-2 rounded text-xs font-mono font-bold bg-[#201f1f] hover:bg-[#2a2a2a] text-white border border-[#353534] light:bg-white light:border-slate-300 light:text-slate-800 transition-colors inline-flex items-center gap-1.5 cursor-pointer"
          >
            <BookOpen className="w-3.5 h-3.5 text-[#00ff41]" />
            <span>EXPLORE DOCS</span>
          </a>
        </div>
      </div>
    </main>
  );
}
