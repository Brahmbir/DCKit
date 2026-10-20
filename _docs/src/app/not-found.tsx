import Link from "next/link";
import {
  Terminal,
  Home,
  BookOpen,
  Layers,
  ArrowRight,
  AlertTriangle,
} from "lucide-react";
import { latestVersion } from "@/lib/shared";

export default function NotFound() {
  const docsBasePath = `/docs${latestVersion.url}`;

  const suggestedLinks = [
    {
      title: "Quickstart Guide",
      category: "Getting Started",
      href: docsBasePath,
      icon: BookOpen,
    },
    {
      title: "API Reference",
      category: "Components",
      href: `${docsBasePath}/api_reference`,
      icon: Layers,
    },
    {
      title: "About DCKit",
      category: "About",
      href: "/about",
      icon: Terminal,
    },
  ];

  return (
    <main className="min-h-[85vh] flex flex-col items-center justify-center px-4 sm:px-6 pt-20 pb-16 font-mono bg-fd-background bg-[radial-gradient(#66706455_0.8px,transparent_0.8px)] bg-position-[0_0] bg-size-[22px_22px]">
      <div className="w-full max-w-3xl flex flex-col items-center text-center">
        {/* Status Pill */}
        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-fd-error/10 border border-fd-error/30 text-xs font-semibold text-fd-error mb-8">
          <AlertTriangle className="w-3.5 h-3.5" />
          <span>STATUS: 404 // ADDRESS_UNRESOLVED</span>
        </div>

        {/* 404 Display */}
        <div className="relative mb-6">
          <span className="font-extrabold text-7xl sm:text-9xl tracking-tight text-fd-primary/90 select-none">
            404
          </span>

          <span className="absolute inset-0 font-extrabold text-7xl sm:text-9xl tracking-tight text-fd-primary opacity-20 blur-sm pointer-events-none select-none">
            404
          </span>
        </div>

        <h1 className="font-bold text-2xl sm:text-3xl text-fd-card-foreground mb-3 tracking-tight">
          Module or Route Not Found
        </h1>

        <p className="text-xs sm:text-sm text-fd-muted-foreground max-w-lg mb-8 leading-relaxed">
          The requested documentation path does not exist or has been relocated
          in the engine pipeline.
        </p>

        {/* Diagnostics Box */}
        <div className="w-full max-w-xl text-left rounded-xl bg-fd-card border border-fd-border p-4 mb-8 text-xs font-mono">
          <div className="flex items-center justify-between pb-2 mb-2 border-b border-fd-border text-fd-muted-foreground text-[11px]">
            <span className="flex items-center gap-1.5">
              <Terminal className="w-3.5 h-3.5 text-fd-primary" />
              <span>sys_router // diagnostics</span>
            </span>

            <span className="text-fd-error font-semibold">[ERR_NOT_FOUND]</span>
          </div>

          <div className="space-y-1">
            <div className="text-fd-muted-foreground">
              <span className="text-fd-primary">&gt;</span>{" "}
              sys_route.resolve(request.pathname)
            </div>

            <div className="text-fd-error/70">
              [ERROR] Failed to map URI to documented node or component
              registry.
            </div>
          </div>
        </div>

        {/* Actions */}
        <div className="flex flex-wrap items-center justify-center gap-3 mb-12">
          <Link
            href="/"
            className="px-5 py-2.5 rounded-lg text-xs font-mono font-bold tracking-wider bg-fd-primary hover:brightness-110 text-fd-primary-foreground transition-all inline-flex items-center gap-2"
          >
            <Home className="w-4 h-4" />
            <span>[ RETURN HOME ]</span>
          </Link>

          <Link
            href="/docs"
            className="px-5 py-2.5 rounded-lg text-xs font-mono font-bold tracking-wider bg-fd-secondary hover:bg-fd-muted text-fd-secondary-foreground border border-fd-border transition-colors inline-flex items-center gap-2"
          >
            <BookOpen className="w-4 h-4 text-fd-primary" />
            <span>BROWSE DOCS</span>
          </Link>
        </div>

        {/* Suggested Links */}
        <div className="w-full max-w-xl text-left">
          <div className="text-xs font-bold text-fd-muted-foreground uppercase tracking-wider mb-3 px-1">
            Suggested Documentation Nodes
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
            {suggestedLinks.map((link) => {
              const Icon = link.icon;

              return (
                <Link
                  key={link.href}
                  href={link.href}
                  className="flex items-center justify-between p-3 rounded-xl bg-fd-card hover:bg-fd-secondary border border-fd-border text-left text-xs transition-all group"
                >
                  <div className="flex items-center gap-2.5 min-w-0">
                    <div className="w-6 h-6 rounded bg-fd-accent text-fd-primary flex items-center justify-center shrink-0">
                      <Icon className="w-3.5 h-3.5" />
                    </div>

                    <div className="min-w-0">
                      <div className="font-semibold text-fd-card-foreground truncate group-hover:text-fd-primary transition-colors">
                        {link.title}
                      </div>

                      <div className="text-[10px] text-fd-muted-foreground">
                        {link.category}
                      </div>
                    </div>
                  </div>

                  <ArrowRight className="w-3.5 h-3.5 text-fd-muted-foreground group-hover:text-fd-primary group-hover:translate-x-0.5 transition-all shrink-0 ml-2" />
                </Link>
              );
            })}
          </div>
        </div>
      </div>
    </main>
  );
}
