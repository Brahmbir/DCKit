"use client";
import React, { useState } from "react";
import { Copy, Check } from "lucide-react";

interface CopyButtonProps {
  textToCopy: string;
  label?: string;
  className?: string;
}

export const CopyButton: React.FC<CopyButtonProps> = ({
  textToCopy,
  label = "COPY",
  className = "",
}) => {
  const [copied, setCopied] = useState(false);

  const handleCopy = async (e: React.MouseEvent) => {
    e.stopPropagation();
    try {
      await navigator.clipboard.writeText(textToCopy);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // Fallback
      const textArea = document.createElement("textarea");
      textArea.value = textToCopy;
      document.body.appendChild(textArea);
      textArea.select();
      document.execCommand("copy");
      document.body.removeChild(textArea);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  return (
    <button
      onClick={handleCopy}
      type="button"
      className={`inline-flex border items-center gap-1.5 px-2.5 py-1 text-xs font-mono tracking-wider transition-colors rounded cursor-pointer ${
        copied
          ? "text-[#00ff41] bg-[#00ff41]/10 border-[#00ff41]/30"
          : "text-neutral-400 hover:text-[#00ff41] border-[#00000000] dark:hover:text-[#00ff41] light:text-neutral-600 hover:bg-neutral-800/40"
      } ${className}`}
      title="Copy to clipboard"
    >
      {copied ? (
        <Check className="w-3.5 h-3.5 text-[#00ff41]" />
      ) : (
        <Copy className="w-3.5 h-3.5" />
      )}
      <span className="font-semibold">{copied ? "COPIED" : label}</span>
    </button>
  );
};
