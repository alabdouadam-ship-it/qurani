"use client";

/**
 * The small presentational pieces both CRUD pages need.
 *
 * `Tag`, `Field`, `Check` and `Section` were defined separately in
 * `app/news/page.tsx` and `app/reciters/page.tsx`. The copies had already
 * drifted — news grew a `hint` on `Field` that reciters never got — and the same
 * drift is what let the two pages disagree about how to tell "new" from "edit"
 * (news inferred it from an empty title until group A fixed it). One definition
 * removes the room for that.
 *
 * Deliberately plain: these read the CSS variables and utility classes already
 * defined in globals.css rather than introducing styling of their own.
 */

import type { ReactNode } from "react";

/** Small muted pill for metadata: a type, a language, a status. */
export function Tag({ children }: { children: ReactNode }) {
  return (
    <span
      className="text-xs px-2 py-0.5 rounded"
      style={{ background: "var(--surface-2)", color: "var(--muted)" }}
    >
      {children}
    </span>
  );
}

/** A titled block, used to separate the current and expired news lists. */
export function Section({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  return (
    <div className="flex flex-col gap-2">
      <h2 className="font-bold muted">{title}</h2>
      {children}
    </div>
  );
}

/** Labelled form control, with an optional explanatory hint underneath.
 *
 *  `hint` is what the reciters copy was missing, which is why its two audio
 *  base-URL fields still have no guidance while the news CSV fields do. */
export function Field({
  label,
  hint,
  children,
}: {
  label: string;
  hint?: string;
  children: ReactNode;
}) {
  return (
    <div>
      <label className="label">{label}</label>
      {children}
      {hint && <div className="muted text-xs mt-1">{hint}</div>}
    </div>
  );
}

/** Checkbox with a clickable label. */
export function Check({
  label,
  checked,
  onChange,
}: {
  label: string;
  checked: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <label className="flex items-center gap-2 cursor-pointer">
      <input
        type="checkbox"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
      />
      <span>{label}</span>
    </label>
  );
}
