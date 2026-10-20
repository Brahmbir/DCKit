import defaultMdxComponents from "fumadocs-ui/mdx";
import { ImageZoom } from "fumadocs-ui/components/image-zoom";
import type { MDXComponents } from "mdx/types";
import type { ComponentProps } from "react";

const base = process.env.NEXT_PUBLIC_BASE_PATH ?? "";

export function getMDXComponents(components?: MDXComponents) {
  return {
    ...defaultMdxComponents,
    img: ({ src, ...props }: ComponentProps<"img">) => {
      const resolved =
        typeof src === "string" && src.startsWith("/") ? `${base}${src}` : src;
      return (
        <ImageZoom
          {...(props as Omit<ComponentProps<typeof ImageZoom>, "src">)}
          src={resolved as string}
        />
      );
    },
    ...components,
  } satisfies MDXComponents;
}

export const useMDXComponents = getMDXComponents;

declare global {
  type MDXProvidedComponents = ReturnType<typeof getMDXComponents>;
}
