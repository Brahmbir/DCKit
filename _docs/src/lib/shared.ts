import { createGetUrl } from "fumadocs-core/source";

export const appName = "DCKit";
export const docsRoute = "/docs";
export const docsImageRoute = "/og/docs";
export const docsContentRoute = "/llms.mdx/docs";

// fill this with your actual GitHub info, for example:
export const gitConfig = {
  user: "Brahmbir",
  repo: "DCKit",
  branch: "main",
};

const getContentUrl = createGetUrl(docsContentRoute);

export function getPageMarkdownUrl(page: { slugs: string[]; locale?: string }) {
  const segments = [...page.slugs, "content.md"];

  return { segments, url: getContentUrl(segments, page.locale) };
}

const getImageUrl = createGetUrl(docsImageRoute);

export function getPageImageUrl(page: { slugs: string[]; locale?: string }) {
  const segments = [...page.slugs, "image.png"];

  return { segments, url: getImageUrl(segments, page.locale) };
}

// region for external data
type Version = {
  label: string;
  url: `/${string}`;
};

export const latestVersion: Version = { label: "1.0.0-rc.1", url: "/v1" };

export const siteUrl = "https://localhost:3000";

export const storeUrl =
  "https://store.godotengine.org/asset/brahm-bir-singh/dckit/";
