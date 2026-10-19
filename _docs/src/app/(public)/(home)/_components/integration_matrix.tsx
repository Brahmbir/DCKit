"use client";

import { useState } from "react";
import { DynamicCodeBlock } from "fumadocs-ui/components/dynamic-codeblock";
import { cn } from "cn";

type CodeTab = "gdscript" | "csharp";

interface IntegrationMatrixProps {
  gdscriptCode?: string;
  csharpCode?: string;
}

const DEFAULT_GDSCRIPT = `extends Node

func _ready() -> void:
    print("DCKit integration ready")
`;

const DEFAULT_CSHARP = `using Godot;

public partial class GameManager : Node
{
    public override void _Ready()
    {
        GD.Print("DCKit integration ready");
    }
}
`;

export default function IntegrationMatrix({
  gdscriptCode = DEFAULT_GDSCRIPT,
  csharpCode = DEFAULT_CSHARP,
}: IntegrationMatrixProps) {
  const [activeTab, setActiveTab] = useState<CodeTab>("gdscript");

  const isGDScript = activeTab === "gdscript";
  const filename = isGDScript ? "camera_rig.gd" : "CameraRig.cs";
  const code = isGDScript ? gdscriptCode : csharpCode;

  const tabClass = (active: boolean) =>
    cn(
      "cursor-pointer rounded px-4 py-1.5 font-mono text-xs font-bold transition-all",
      active
        ? "bg-fd-background text-fd-primary shadow-sm"
        : "text-fd-muted-foreground hover:text-fd-foreground",
    );

  return (
    <section className="mx-auto w-full max-w-5xl px-4 py-12 sm:px-6">
      <div className="flex flex-col gap-6">
        <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-end">
          <div>
            <span className="font-mono text-xs font-bold tracking-widest text-fd-primary">
              INTEGRATION
            </span>

            <h2 className="mt-1 font-display text-2xl font-bold text-fd-foreground sm:text-3xl">
              Zero-Friction Setup
            </h2>
          </div>

          <div
            role="tablist"
            aria-label="Programming language"
            className="flex items-center gap-1 rounded border border-fd-border bg-fd-muted p-1"
          >
            <button
              id="gdscript-tab"
              type="button"
              role="tab"
              aria-selected={isGDScript}
              aria-controls="integration-code"
              onClick={() => setActiveTab("gdscript")}
              className={tabClass(isGDScript)}
            >
              GDScript
            </button>

            <button
              id="csharp-tab"
              type="button"
              role="tab"
              aria-selected={!isGDScript}
              aria-controls="integration-code"
              onClick={() => setActiveTab("csharp")}
              className={tabClass(!isGDScript)}
            >
              C# (.NET)
            </button>
          </div>
        </div>

        <div className="relative overflow-hidden rounded-lg border border-fd-border bg-fd-card shadow-2xl">
          {/* File header */}
          <div className="flex items-center justify-between border-b border-fd-border px-5 py-3 font-mono text-xs">
            <div className="flex items-center gap-2">
              <span className="h-2.5 w-2.5 rounded-full bg-red-500/80" />
              <span className="h-2.5 w-2.5 rounded-full bg-amber-500/80" />
              <span className="h-2.5 w-2.5 rounded-full bg-emerald-500/80" />

              <span className="ml-2 font-semibold text-fd-muted-foreground">
                {filename}
              </span>
            </div>
          </div>

          <div
            id="integration-code"
            role="tabpanel"
            aria-labelledby={isGDScript ? "gdscript-tab" : "csharp-tab"}
            className="overflow-x-auto text-left text-xs sm:text-sm"
          >
            <DynamicCodeBlock
              key={activeTab}
              lang={isGDScript ? "gdscript" : "csharp"}
              code={code}
              codeblock={{
                keepBackground: false,
                className:
                  "my-0 rounded-none border-0 bg-transparent shadow-none",
              }}
            />
          </div>
        </div>
      </div>
    </section>
  );
}
