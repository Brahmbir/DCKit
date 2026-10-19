import { Layers, Terminal, ListClock } from "lucide-react";

export interface IPillarCardsProps {}

export function PillarCards(props: IPillarCardsProps) {
  return (
    <section className="w-full max-w-6xl mx-auto px-4 sm:px-6 py-12">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* PIL-01: Command History & Autocomplete */}
        <div className="p-6 sm:p-8 rounded-lg bg-[#1c1b1b] border border-[#2a2a2a] hover:border-[#3b4b37] light:bg-white light:border-slate-200 light:hover:border-emerald-300 transition-all flex flex-col justify-between group shadow-lg">
          <div>
            <div className="flex items-center justify-between mb-6">
              <span className="font-mono text-xs font-bold tracking-widest text-[#00ff41]">
                PIL-01
              </span>
              <div className="p-2 rounded bg-[#00ff41]/10 text-[#00ff41] group-hover:scale-110 transition-transform">
                <ListClock className="w-5 h-5" />
              </div>
            </div>
            <h3 className="font-display font-bold text-xl sm:text-2xl text-white light:text-slate-900 mb-2">
              Command History & Autocomplete
            </h3>
            <p className="font-mono text-xs text-[#b9ccb2] light:text-slate-600 leading-relaxed">
              Speed up your workflow with command suggestions and instant
              completion. Recall previous commands, navigate execution history,
              and discover available commands without leaving the console.
            </p>
          </div>
          <div className="mt-8 pt-4 border-t border-[#2a2a2a] light:border-slate-100 flex items-center justify-between text-xs font-mono">
            <span className="text-[#00ff41] font-semibold">REACTIVE SYNC</span>
            <span className="text-neutral-500 light:text-slate-400">
              HISTORY RECALL
            </span>
          </div>
        </div>

        {/* PIL-02: Batch Runner */}
        <div className="p-6 sm:p-8 rounded-lg bg-[#1c1b1b] border border-[#2a2a2a] hover:border-[#3b4b37] light:bg-white light:border-slate-200 light:hover:border-cyan-300 transition-all flex flex-col justify-between group shadow-lg">
          <div>
            <div className="flex items-center justify-between mb-6">
              <span className="font-mono text-xs font-bold tracking-widest text-[#00e5ff]">
                PIL-02
              </span>
              <div className="p-2 rounded bg-[#00e5ff]/10 text-[#00e5ff] group-hover:scale-110 transition-transform">
                <Layers className="w-5 h-5" />
              </div>
            </div>
            <h3 className="font-display font-bold text-xl sm:text-2xl text-white light:text-slate-900 mb-2">
              Batch Runner
            </h3>
            <p className="font-mono text-xs text-[#b9ccb2] light:text-slate-600 leading-relaxed">
              Script complex sequences, chain commands with semicolons, and run
              automated <code className="text-[#00e5ff]">.txt</code> batch files
              for reproducible QA testing, stress passes, and automated
              scenarios.
            </p>
          </div>
          <div className="mt-8 pt-4 border-t border-[#2a2a2a] light:border-slate-100 flex items-center justify-between text-xs font-mono">
            <span className="text-[#00e5ff] font-semibold">SCRIPT CHAINS</span>
            <span className="text-neutral-500 light:text-slate-400">
              AUTOMATION MACROS
            </span>
          </div>
        </div>

        {/* PIL-03: Simple Syntax */}
        <div className="p-6 sm:p-8 rounded-lg bg-[#1c1b1b] border border-[#2a2a2a] hover:border-[#3b4b37] light:bg-white light:border-slate-200 light:hover:border-amber-300 transition-all flex flex-col justify-between group shadow-lg">
          <div>
            <div className="flex items-center justify-between mb-6">
              <span className="font-mono text-xs font-bold tracking-widest text-[#ffb300]">
                PIL-03
              </span>
              <div className="p-2 rounded bg-[#ffb300]/10 text-[#ffb300] group-hover:scale-110 transition-transform">
                <Terminal className="w-5 h-5" />
              </div>
            </div>
            <h3 className="font-display font-bold text-xl sm:text-2xl text-white light:text-slate-900 mb-2">
              Simple Syntax
            </h3>
            <p className="font-mono text-xs text-[#b9ccb2] light:text-slate-600 leading-relaxed">
              Ergonomic, forgiving parser supporting positional arguments,
              fallbacks (
              <code className="text-[#ffb300]">$name:"default_name"</code>),
              constructors, quoted strings, and inline comments (
              <code className="text-[#ffb300]">#</code>).
            </p>
          </div>
          <div className="mt-8 pt-4 border-t border-[#2a2a2a] light:border-slate-100 flex items-center justify-between text-xs font-mono">
            <span className="text-[#ffb300] font-semibold">ZERO FRICTION</span>
            <span className="text-neutral-500 light:text-slate-400">
              FAILSAFE PARSING
            </span>
          </div>
        </div>
      </div>
    </section>
  );
}
