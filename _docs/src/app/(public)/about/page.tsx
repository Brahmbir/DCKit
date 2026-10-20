import MeTag from "@/components/MeTag";
import { baseOptions } from "@/lib/layout.shared";
import { latestVersion } from "@/lib/shared";
import { ExternalLink, Code2, Heart, Shield, BookOpen } from "lucide-react";

export default function AboutPage() {
  return (
    <main className="mx-auto max-w-4xl px-4 sm:px-6 pt-24 pb-20 font-mono">
      {/* Header Badge */}
      <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-fd-muted border border-fd-border text-xs text-fd-primary mb-6">
        <span className="w-2 h-2 rounded-full bg-fd-primary" />
        <span>// PROJECT OVERVIEW</span>
      </div>

      {/* Title */}
      <h1 className="font-display font-bold text-3xl sm:text-5xl text-fd-foreground tracking-tight mb-6">
        About DCKit
      </h1>

      {/* Lead Paragraph */}
      <p className="text-sm sm:text-base text-fd-muted-foreground leading-relaxed mb-12">
        DCKit is an extensible, full-featured in-game developer console built
        from the ground up for Godot 4. Developed and maintained by{" "}
        <MeTag variant="link" />, it provides developers with a complete command
        pipeline, syntax-highlighted input, autocompletion, reactive variable
        binding, and automated batch scripting directly inside running game
        sessions.
      </p>

      {/* Philosophy & Architecture */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-12">
        {/* GDScript & C# */}
        <div className="p-6 rounded-lg bg-fd-card border border-fd-border">
          <div className="flex items-center gap-2.5 text-pillar-2 font-bold text-sm mb-3">
            <Code2 className="w-4 h-4" />
            <span>GDScript & C# First-Class Parity</span>
          </div>

          <p className="text-xs text-fd-muted-foreground leading-relaxed">
            Whether your project is pure GDScript or uses Godot .NET / C#, DCKit
            provides strongly typed callback bindings, natural lambda delegates,
            and seamless cross-language variable sharing.
          </p>
        </div>

        {/* Open Source */}
        <div className="p-6 rounded-lg bg-fd-card border border-fd-border">
          <div className="flex items-center gap-2.5 text-pillar-1 font-bold text-sm mb-3">
            <Shield className="w-4 h-4" />
            <span>Open Source & Community Driven</span>
          </div>

          <p className="text-xs text-fd-muted-foreground leading-relaxed">
            DCKit is completely open-source under the MIT license. Feedback,
            issues, feature requests, and pull requests are welcomed on the
            official GitHub repository.
          </p>
        </div>
      </div>

      {/* Technical Specifications */}
      <div className="rounded-lg bg-fd-card border border-fd-border p-6 mb-12">
        <h2 className="font-display font-bold text-xl text-fd-foreground mb-4">
          Engine Specifications
        </h2>

        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 text-xs">
          <div>
            <div className="text-fd-muted-foreground">ENGINE VERSION</div>
            <div className="text-fd-foreground font-semibold mt-1">
              Godot 4.5+
            </div>
          </div>

          <div>
            <div className="text-fd-muted-foreground">RELEASE STAGE</div>
            <div className="text-pillar-1 font-semibold mt-1">
              {latestVersion.label.toUpperCase()}
            </div>
          </div>

          <div>
            <div className="text-fd-muted-foreground">LANGUAGES</div>
            <div className="text-fd-foreground font-semibold mt-1">
              GDScript & C#
            </div>
          </div>

          <div>
            <div className="text-fd-muted-foreground">LICENSE</div>
            <div className="text-fd-foreground font-semibold mt-1">
              MIT License
            </div>
          </div>
        </div>
      </div>

      {/* Author & Links */}
      <div className="p-6 rounded-lg bg-fd-muted border border-fd-border flex flex-col sm:flex-row items-start sm:items-center justify-between gap-6">
        <div>
          <div className="text-fd-foreground font-bold text-sm flex items-center gap-2">
            <span>
              Created by <MeTag />
            </span>
            <Heart className="w-3.5 h-3.5 text-red-500 fill-current" />
          </div>

          <p className="text-xs text-fd-muted-foreground mt-1">
            Building game development and runtime diagnostic tooling for Godot
            4.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <a
            href={baseOptions().githubUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="px-4 py-2 rounded text-xs font-mono font-bold bg-fd-primary hover:brightness-110 text-fd-primary-foreground transition-all inline-flex items-center gap-1.5 cursor-pointer"
          >
            <span>GITHUB REPOSITORY</span>
            <ExternalLink className="w-3.5 h-3.5" />
          </a>

          <a
            href={"/docs" + latestVersion.url}
            target="_blank"
            className="px-4 py-2 rounded text-xs font-mono font-bold bg-fd-card hover:bg-fd-accent text-fd-foreground border border-fd-border transition-colors inline-flex items-center gap-1.5 cursor-pointer"
          >
            <BookOpen className="w-3.5 h-3.5 text-fd-primary" />
            <span>EXPLORE DOCS</span>
          </a>
        </div>
      </div>
    </main>
  );
}
