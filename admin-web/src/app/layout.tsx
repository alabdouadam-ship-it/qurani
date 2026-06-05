import type { Metadata } from "next";
import { Geist } from "next/font/google";
import "./globals.css";
import { UiProvider } from "@/lib/ui-context";
import { AuthProvider } from "@/lib/auth-context";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "Qurani Admin",
  description: "Admin dashboard for the Qurani app (Supabase).",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" data-theme="light" className={`${geistSans.variable} h-full`}>
      <body className="min-h-full">
        <UiProvider>
          <AuthProvider>{children}</AuthProvider>
        </UiProvider>
      </body>
    </html>
  );
}
