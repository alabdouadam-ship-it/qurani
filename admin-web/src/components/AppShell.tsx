"use client";

import { useEffect } from "react";
import { useRouter, usePathname } from "next/navigation";
import Link from "next/link";
import { useAuth } from "@/lib/auth-context";
import { useUi } from "@/lib/ui-context";
import { Controls } from "./Controls";

/**
 * Authenticated app shell: redirects to /login when there's no admin session,
 * and renders the sidebar + top bar around the page content.
 */
export function AppShell({ children }: { children: React.ReactNode }) {
  const { loading, admin, signOut } = useAuth();
  const { t } = useUi();
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    if (!loading && !admin) router.replace("/login");
  }, [loading, admin, router]);

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center muted">
        {t.loading}
      </div>
    );
  }
  if (!admin) return null; // redirecting

  const nav = [
    { href: "/dashboard", label: t.dashboard },
    { href: "/news", label: t.news },
    { href: "/reciters", label: t.reciters },
    { href: "/account", label: t.account },
  ];

  return (
    <div className="min-h-screen flex flex-col">
      <header
        className="flex items-center justify-between gap-3 px-4 py-3 card"
        style={{ borderRadius: 0, borderInline: "none", borderTop: "none" }}
      >
        <div className="flex items-center gap-3">
          <span className="font-bold text-lg">{t.appTitle}</span>
        </div>
        <div className="flex items-center gap-3">
          <span className="muted text-sm hidden sm:inline">{admin.name}</span>
          <Controls />
          <button className="btn btn-ghost" onClick={() => signOut()}>
            {t.logout}
          </button>
        </div>
      </header>

      <div className="flex flex-1">
        <nav
          className="card p-2 m-3 flex sm:flex-col gap-1 h-fit"
          style={{ minWidth: 160 }}
        >
          {nav.map((item) => {
            const active = pathname === item.href;
            return (
              <Link
                key={item.href}
                href={item.href}
                className="btn"
                style={{
                  justifyContent: "flex-start",
                  background: active ? "var(--surface-2)" : "transparent",
                  color: "var(--text)",
                  fontWeight: active ? 700 : 500,
                }}
              >
                {item.label}
              </Link>
            );
          })}
        </nav>
        <main className="flex-1 p-3 max-w-5xl">{children}</main>
      </div>
    </div>
  );
}
