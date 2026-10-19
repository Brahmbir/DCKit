import { ExternalLink } from "lucide-react";
import { storeUrl } from "@/lib/shared";
import { baseOptions } from "@/lib/layout.shared";
import MeTag from "@/components/MeTag";

type Props = {};

export default function Footer({}: Props) {
  const githubUrl = baseOptions().githubUrl ?? "/";

  return (
    <footer className="w-full border-t border-fd-border bg-fd-background py-8">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 flex flex-col md:flex-row items-center justify-between gap-4 font-mono text-xs">
        <div className="flex flex-col gap-1 text-center md:text-left">
          <div className="flex items-center gap-2 text-fd-muted-foreground justify-center md:justify-start">
            <span className="text-fd-primary font-bold">&gt;</span>
            <span>DCKIT INTERFACE STACK // GODOT 4 ENGINE READY</span>
          </div>

          <p className="text-fd-muted-foreground">
            © {new Date().getFullYear()} DCKIT PROTOCOL · MAINTAINED BY{" "}
            <MeTag className="uppercase" />
          </p>
        </div>

        <div className="flex items-center gap-4 text-fd-muted-foreground">
          <a
            href={storeUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="hover:text-fd-primary transition-colors inline-flex items-center gap-1"
          >
            <span>GODOT ASSET STORE</span>
            <ExternalLink className="w-3 h-3" />
          </a>

          <span>·</span>

          <a
            href={githubUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="hover:text-fd-primary transition-colors inline-flex items-center gap-1"
          >
            <span>GITHUB REPO</span>
            <ExternalLink className="w-3 h-3" />
          </a>
        </div>
      </div>
    </footer>
  );
}
