"use client";

import { useState } from "react";
import { initials } from "@/lib/format";

const SIZES = { sm: "h-9 w-9 text-xs", md: "h-10 w-10 text-sm", lg: "h-14 w-14 text-lg" } as const;

/** Profile photo from the avatars bucket, falling back to initials. */
export function Avatar({ name, url, size = "sm", accent = false }: {
  name: string | null | undefined; url?: string | null; size?: keyof typeof SIZES; accent?: boolean;
}) {
  const [broken, setBroken] = useState(false);
  const base = `grid shrink-0 place-items-center overflow-hidden rounded-full font-semibold ${SIZES[size]} ${
    accent ? "bg-gradient-to-br from-royal to-cyan" : "bg-white/10"}`;
  if (!url || broken) return <div className={base} aria-hidden>{initials(name)}</div>;
  return (
    // Plain <img>: photos come from Supabase Storage, which next/image would need configuring for.
    // eslint-disable-next-line @next/next/no-img-element
    <img src={url} alt={name ? `${name}'s profile photo` : "Profile photo"} loading="lazy"
      onError={() => setBroken(true)} className={`${base} object-cover`} />
  );
}
