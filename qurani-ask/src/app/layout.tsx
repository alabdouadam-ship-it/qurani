import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import { ThemeProvider } from 'next-themes';
import { AuthProvider } from '@/lib/auth-context';
import { LangProvider } from '@/lib/lang-context';
import './globals.css';

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap',
});

export const metadata: Metadata = {
  title: 'قرآني AI | Qurani AI',
  description: 'مساعد إسلامي ذكي مبني على القرآن الكريم والحديث النبوي والتفسير · Islamic AI assistant grounded in Quran, Tafsir and Hadith',
  icons: { icon: '/favicon.ico' },
  openGraph: {
    title: 'قرآني AI | Qurani AI',
    description: 'اسأل عن الإسلام بمصادر موثقة من القرآن والحديث والتفسير',
    type: 'website',
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    // Default Arabic-first: lang="ar" dir="rtl"
    // LangProvider updates these client-side when user switches to English
    <html lang="ar" dir="rtl" suppressHydrationWarning>
      <head>
        {/* Google Fonts preconnect for Amiri Arabic font */}
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
      </head>
      <body className={`${inter.variable} antialiased`}>
        <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
          <AuthProvider>
            <LangProvider>
              {children}
            </LangProvider>
          </AuthProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
