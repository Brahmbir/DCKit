import { ExternalLink } from "lucide-react";
import { storeUrl } from "@/lib/shared";
import { baseOptions } from "@/lib/layout.shared";

export default function FooterResources() {
  return (
    <div className="mt-4 pt-2 border-t border-[#2a2a2a] light:border-slate-200 text-xs font-mono space-y-2">
      <div className="text-neutral-400 font-semibold">Resources</div>
      <a
        href={storeUrl}
        target="_blank"
        rel="noopener noreferrer"
        className="flex items-center gap-1.5 text-neutral-400 hover:text-[#00ff41] transition-colors"
      >
        <ExternalLink className="w-3.5 h-3.5" />
        <span>Godot Asset Library</span>
      </a>
      <a
        href={baseOptions().githubUrl + "/issues"}
        target="_blank"
        rel="noopener noreferrer"
        className="flex items-center gap-1.5 text-neutral-400 hover:text-[#00ff41] transition-colors"
      >
        <ExternalLink className="w-3.5 h-3.5" />
        <span>Report an Issue</span>
      </a>
    </div>
  );
}
