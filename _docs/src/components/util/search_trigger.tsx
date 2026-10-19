"use client";

import { useEffect, useState } from "react";
import type { FC } from "react";
import { Search } from "lucide-react";
import { useSearchContext } from "fumadocs-ui/contexts/search";
import type {
  FullSearchTriggerProps,
  SearchTriggerProps,
} from "fumadocs-ui/layouts/shared/slots/search-trigger";

function useIsMac() {
  const [isMac, setIsMac] = useState(false);

  useEffect(() => {
    setIsMac(/(Mac|iPhone|iPod|iPad)/i.test(navigator.userAgent));
  }, []);

  return isMac;
}

export const SearchTriggerSM: FC<SearchTriggerProps> = ({
  hideIfDisabled,
  color: _color,
  variant: _variant,
  size: _size,
  className = "",
  onClick,
  children: _children,
  ...props
}) => {
  const isMac = useIsMac();
  const { enabled, setOpenSearch } = useSearchContext();

  if (!enabled && hideIfDisabled) return null;

  return (
    <button
      {...props}
      type="button"
      disabled={!enabled}
      aria-label="Open search dialog"
      title={`Search (${isMac ? "⌘ K" : "Ctrl + K"})`}
      onClick={(e) => {
        onClick?.(e);
        setOpenSearch(true);
      }}
      className={`flex items-center justify-center w-8 h-8 rounded-lg bg-[#201f1f] hover:bg-[#2a2a2a] text-[#b9ccb2] hover:text-white border border-[#2a2a2a] hover:border-[#3b4b37] light:bg-slate-100 light:hover:bg-slate-200 light:border-slate-300 light:text-slate-700 transition-all cursor-pointer group shadow-sm disabled:opacity-50 disabled:cursor-not-allowed ${className}`}
    >
      <Search className="w-3.5 h-3.5 text-[#00ff41] light:text-emerald-600 group-hover:scale-110 transition-transform" />
    </button>
  );
};

export const SearchTriggerFull: FC<FullSearchTriggerProps> = ({
  hideIfDisabled,
  className = "",
  onClick,
  children: _children,
  ...props
}) => {
  const isMac = useIsMac();
  const { enabled, setOpenSearch } = useSearchContext();

  if (!enabled && hideIfDisabled) return null;

  return (
    <button
      {...props}
      type="button"
      disabled={!enabled}
      aria-label="Open search dialog"
      onClick={(e) => {
        onClick?.(e);
        setOpenSearch(true);
      }}
      className={`w-full flex items-center justify-between gap-3 px-3 py-1.5 rounded-lg bg-[#201f1f] hover:bg-[#262626] text-[#b9ccb2] hover:text-white border border-[#2a2a2a] hover:border-[#3b4b37]/80 light:bg-slate-100 light:hover:bg-slate-200/80 light:border-slate-300 light:text-slate-700 transition-all text-xs font-mono cursor-pointer shadow-sm group disabled:opacity-50 disabled:cursor-not-allowed ${className}`}
    >
      <div className="flex items-center gap-2 min-w-0">
        <Search className="w-3.5 h-3.5 text-[#00ff41] light:text-emerald-600 group-hover:scale-110 transition-transform shrink-0" />
        <span className="font-semibold tracking-wider text-xs truncate text-white light:text-slate-800">
          Search
        </span>
      </div>
      <kbd className="inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded text-[10px] font-semibold bg-[#0e0e0e] border border-[#353534] text-neutral-400 group-hover:text-[#00ff41] light:bg-white light:border-slate-300 light:text-slate-600 transition-colors shrink-0 shadow-xs">
        {isMac ? "⌘ + K" : "Ctrl + K"}
      </kbd>
    </button>
  );
};
