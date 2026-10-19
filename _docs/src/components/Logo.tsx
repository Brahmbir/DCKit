"use client";
import Image from "next/image";
import React from "react";

interface LogoProps {
  name?: string;
}

export const Logo: React.FC<LogoProps> = ({ name }) => {
  return (
    <div className="flex items-center gap-2 text-left shrink-0 group">
      <div className="w-8 h-8 flex items-center justify-center text-fd-primary group-hover:scale-105 transition-transform">
        <Image
          src="/logos/icon.svg"
          alt="DCKit Icon"
          width={20}
          height={20}
          className="w-full h-full p-1"
        />
      </div>
      {name && (
        <div className="flex items-center gap-2">
          <span className="font-display font-bold text-lg sm:text-xl tracking-tight  light:text-slate-900 group-hover:text-fd-primary transition-colors">
            {name}
          </span>
        </div>
      )}
    </div>
  );
};
