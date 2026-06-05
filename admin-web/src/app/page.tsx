"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";
import { useUi } from "@/lib/ui-context";

export default function Home() {
  const { loading, admin } = useAuth();
  const { t } = useUi();
  const router = useRouter();

  useEffect(() => {
    if (loading) return;
    router.replace(admin ? "/dashboard" : "/login");
  }, [loading, admin, router]);

  return (
    <div className="min-h-screen flex items-center justify-center muted">
      {t.loading}
    </div>
  );
}
