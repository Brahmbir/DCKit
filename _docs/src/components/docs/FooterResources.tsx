import { ExternalLink } from "lucide-react";
import { storeUrl } from "@/lib/shared";
import { baseOptions } from "@/lib/layout.shared";
import Link from "next/link";

export default function FooterResources() {
  return (
    <div className="mt-4 pt-2 border-t border-fd-foreground/10 text-xs font-mono space-y-2">
      <div className="text-fd-foreground font-semibold">Resources</div>
      <Link
        href={storeUrl}
        target="_blank"
        rel="noopener noreferrer"
        className="flex items-center gap-1.5 text-fd-muted-foreground hover:text-fd-primary transition-colors"
      >
        <ExternalLink className="w-3.5 h-3.5" />
        <span>Godot Asset Library</span>
      </Link>
      <Link
        href={baseOptions().githubUrl + "/issues"}
        target="_blank"
        rel="noopener noreferrer"
        className="flex items-center gap-1.5 text-fd-muted-foreground hover:text-fd-primary transition-colors"
      >
        <ExternalLink className="w-3.5 h-3.5" />
        <span>Report an Issue</span>
      </Link>
    </div>
  );
}
