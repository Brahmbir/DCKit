import { HomeLayout } from "fumadocs-ui/layouts/home";
import { baseOptions } from "@/lib/layout.shared";

export default function Layout({ children }: LayoutProps<"/">) {
  return (
    <HomeLayout
      style={{
        backgroundColor: "#101110",
        backgroundImage: "radial-gradient(#66706455 0.8px, transparent 0.8px)",
        backgroundPosition: "0 0",
        backgroundSize: "22px 22px",
      }}
      themeSwitch={{ enabled: false }}
      {...baseOptions()}
    >
      {children}
    </HomeLayout>
  );
}
