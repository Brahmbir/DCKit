import NextImage, { type ImageProps } from "next/image";

export default function Image({ src, ...props }: ImageProps) {
  const base = process.env.NEXT_PUBLIC_BASE_PATH ?? "";
  const resolved =
    typeof src === "string" && src.startsWith("/") ? `${base}${src}` : src;

  return <NextImage src={resolved} {...props} />;
}
