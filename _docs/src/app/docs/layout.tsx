import { source } from "@/lib/source";
import { DocsLayout } from "fumadocs-ui/layouts/docs";
import { baseOptions } from "@/lib/layout.shared";

import FooterResources from "@/components/docs/FooterResources";

export default function Layout({ children }: LayoutProps<"/docs">) {
  return (
    <DocsLayout
      sidebar={{
        banner: (
          <div className="px-4 py-2 border-b border-[#2a2a2a] light:border-slate-200">
            <h1 className="text-lg font-semibold">DCKit</h1>
            <p className="text-sm text-neutral-400">
              A Godot 4.5+ plugin for In-Game Console.
            </p>
          </div>
        ),
        footer: <FooterResources />,
      }}
      containerProps={{}}
      slots={{
        searchTrigger: false,
      }}
      themeSwitch={{ enabled: false }}
      tree={source.getPageTree()}
      {...baseOptions()}
    >
      {children}
    </DocsLayout>
  );
}
