import type { BaseLayoutProps } from "fumadocs-ui/layouts/shared";
import { appName, gitConfig } from "./shared";
import { Logo } from "@/components/Logo";

export function baseOptions(): BaseLayoutProps {
  return {
    nav: {
      title: <Logo name={appName} />,
    },
    links: [
      { text: "DOCS", url: "/docs", on: "nav", active: "nested-url" },
      {
        text: "API REFERENCE",
        url: "/api_reference",
        on: "nav",
        active: "nested-url",
      },
      { text: "ABOUT", url: "/about", on: "nav" },
    ],
    githubUrl: `https://github.com/${gitConfig.user}/${gitConfig.repo}`,
  };
}
