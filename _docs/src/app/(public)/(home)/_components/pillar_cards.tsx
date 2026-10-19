import { Layers, Terminal, ListClock } from "lucide-react";

export interface IPillarCardsProps {}

export function PillarCards(props: IPillarCardsProps) {
  return (
    <section className="w-full max-w-6xl mx-auto px-4 sm:px-6 py-12">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* PIL-01: Command History & Autocomplete */}
        <div className="p-6 sm:p-8 rounded-lg bg-fd-card text-fd-card-foreground border border-fd-border hover:border-fd-primary transition-all flex flex-col justify-between group shadow-lg">
          <div>
            <div className="flex items-center justify-between mb-6">
              <span className="font-mono text-xs font-bold tracking-widest text-pillar-1">
                PIL-01
              </span>
              <div className="p-2 rounded bg-pillar-1-bg text-pillar-1 group-hover:scale-110 transition-transform">
                <ListClock className="w-5 h-5" />
              </div>
            </div>

            <h3 className="font-display font-bold text-xl sm:text-2xl text-fd-foreground mb-2">
              Command History & Autocomplete
            </h3>

            <p className="font-mono text-xs text-fd-muted-foreground leading-relaxed">
              Speed up your workflow with command suggestions and instant
              completion. Recall previous commands, navigate execution history,
              and discover available commands without leaving the console.
            </p>
          </div>

          <div className="mt-8 pt-4 border-t border-fd-border flex items-center justify-between text-xs font-mono">
            <span className="text-pillar-1 font-semibold">REACTIVE SYNC</span>
            <span className="text-fd-muted-foreground">HISTORY RECALL</span>
          </div>
        </div>

        {/* PIL-02: Batch Runner */}
        <div className="p-6 sm:p-8 rounded-lg bg-fd-card text-fd-card-foreground border border-fd-border hover:border-fd-primary transition-all flex flex-col justify-between group shadow-lg">
          <div>
            <div className="flex items-center justify-between mb-6">
              <span className="font-mono text-xs font-bold tracking-widest text-pillar-2">
                PIL-02
              </span>
              <div className="p-2 rounded bg-pillar-2-bg text-pillar-2 group-hover:scale-110 transition-transform">
                <Layers className="w-5 h-5" />
              </div>
            </div>

            <h3 className="font-display font-bold text-xl sm:text-2xl text-fd-foreground mb-2">
              Batch Runner
            </h3>

            <p className="font-mono text-xs text-fd-muted-foreground leading-relaxed">
              Script complex sequences, chain commands with semicolons, and run
              automated <code className="text-pillar-2">.txt</code> batch files
              for reproducible QA testing, stress passes, and automated
              scenarios.
            </p>
          </div>

          <div className="mt-8 pt-4 border-t border-fd-border flex items-center justify-between text-xs font-mono">
            <span className="text-pillar-2 font-semibold">SCRIPT CHAINS</span>
            <span className="text-fd-muted-foreground">AUTOMATION MACROS</span>
          </div>
        </div>

        {/* PIL-03: Simple Syntax */}
        <div className="p-6 sm:p-8 rounded-lg bg-fd-card text-fd-card-foreground border border-fd-border hover:border-fd-primary transition-all flex flex-col justify-between group shadow-lg">
          <div>
            <div className="flex items-center justify-between mb-6">
              <span className="font-mono text-xs font-bold tracking-widest text-pillar-3">
                PIL-03
              </span>
              <div className="p-2 rounded bg-pillar-3-bg text-pillar-3 group-hover:scale-110 transition-transform">
                <Terminal className="w-5 h-5" />
              </div>
            </div>

            <h3 className="font-display font-bold text-xl sm:text-2xl text-fd-foreground mb-2">
              Simple Syntax
            </h3>

            <p className="font-mono text-xs text-fd-muted-foreground leading-relaxed">
              Ergonomic, forgiving parser supporting positional arguments,
              fallbacks (
              <code className="text-pillar-3">$name:"default_name"</code>),
              constructors, quoted strings, and inline comments (
              <code className="text-pillar-3">#</code>).
            </p>
          </div>

          <div className="mt-8 pt-4 border-t border-fd-border flex items-center justify-between text-xs font-mono">
            <span className="text-pillar-3 font-semibold">ZERO FRICTION</span>
            <span className="text-fd-muted-foreground">FAILSAFE PARSING</span>
          </div>
        </div>
      </div>
    </section>
  );
}
