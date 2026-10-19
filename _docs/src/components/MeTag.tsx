import { ArrowUpRight } from "lucide-react";

interface IMeTagProps {
  variant?: "flat" | "link";
  className?: string;
}

export default function MeTag({
  variant = "flat",
  className = "",
}: IMeTagProps) {
  const baseStyles =
    "group inline-flex items-center gap-0.5 rounded-sm font-semibold transition-colors " +
    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-fd-primary/50";

  const variantStyles = {
    flat: "hover:text-fd-primary",
    link: "underline decoration-fd-primary/40 underline-offset-4 hover:text-fd-primary hover:decoration-fd-primary",
  };

  return (
    <a
      href="https://brahmbir.dev"
      target="_blank"
      rel="noopener noreferrer"
      aria-label="Visit Brahmbir's website (opens in a new tab)"
      className={`${baseStyles} ${variantStyles[variant]} ${className}`}
    >
      <span>Brahmbir</span>

      {variant === "link" && (
        <ArrowUpRight
          aria-hidden="true"
          className="size-3.5 text-fd-muted-foreground transition-all duration-200 group-hover:translate-x-0.5 group-hover:-translate-y-0.5 group-hover:text-fd-primary"
        />
      )}
    </a>
  );
}
