"use client";

import React, { useState } from "react";
import {
  SearchDialog,
  SearchDialogClose,
  SearchDialogContent,
  SearchDialogFooter,
  SearchDialogHeader,
  SearchDialogIcon,
  SearchDialogInput,
  SearchDialogList,
  SearchDialogOverlay,
  type SharedProps,
} from "fumadocs-ui/components/dialog/search";
import { useStaticSearch } from "fumadocs-core/search/client";
import { useI18n } from "fumadocs-ui/contexts/i18n";
import { Sparkles } from "lucide-react";

export default function DefaultSearchDialog(props: SharedProps) {
  const { locale } = useI18n();

  const search = useStaticSearch({
    locale,
  });

  return (
    <SearchDialog {...search} {...props}>
      <SearchDialogOverlay className="fixed inset-0 z-50 bg-black/60 backdrop-blur-md transition-opacity duration-200" />

      <SearchDialogContent className="fixed left-1/2 top-16 sm:top-24 -translate-x-1/2 z-50 w-full max-w-2xl rounded-2xl bg-fd-popover border border-fd-border shadow-2xl overflow-hidden font-mono text-xs flex flex-col max-h-[85vh] animate-in fade-in-0 zoom-in-95 duration-150">
        <SearchDialogHeader className="relative flex items-center gap-3 px-4 py-3.5 border-b border-fd-border bg-fd-card">
          <div className="flex items-center justify-center w-7 h-7 rounded-lg bg-fd-accent border border-fd-border text-fd-primary shrink-0">
            <SearchDialogIcon className="w-3.5 h-3.5 text-fd-primary" />
          </div>

          <SearchDialogInput
            placeholder="Type a command, component, or doc topic..."
            className="flex-1 bg-transparent text-sm font-medium text-fd-foreground placeholder:text-fd-muted-foreground focus:outline-none"
          />

          <SearchDialogClose className="p-1 rounded text-fd-muted-foreground hover:text-fd-foreground transition-colors cursor-pointer hidden sm:inline-flex items-center gap-1 px-2 py-0.5 text-[10px] font-semibold bg-fd-muted border border-fd-border shadow-sm">
            ESC
          </SearchDialogClose>
        </SearchDialogHeader>

        <SearchDialogList />

        <SearchDialogFooter className="p-3 bg-fd-card border-t border-fd-border text-[11px] text-fd-muted-foreground flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-3">
            <span className="flex items-center gap-1">
              <kbd className="px-1.5 py-0.5 rounded bg-fd-muted border border-fd-border text-fd-muted-foreground font-bold">
                ↑↓
              </kbd>
              <span>to navigate</span>
            </span>

            <span className="flex items-center gap-1">
              <kbd className="px-1.5 py-0.5 rounded bg-fd-muted border border-fd-border text-fd-muted-foreground font-bold">
                ↵
              </kbd>
              <span>to select</span>
            </span>

            <span className="flex items-center gap-1">
              <kbd className="px-1.5 py-0.5 rounded bg-fd-muted border border-fd-border text-fd-muted-foreground font-bold">
                ESC
              </kbd>
              <span>to close</span>
            </span>
          </div>

          <div className="flex items-center gap-1.5 text-fd-primary font-bold">
            <Sparkles className="w-3.5 h-3.5" />
            <span>Fumadocs Search · DCKit</span>
          </div>
        </SearchDialogFooter>
      </SearchDialogContent>
    </SearchDialog>
  );
}
