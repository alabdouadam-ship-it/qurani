'use client';

import React, { useCallback, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import {
  MessageSquarePlus,
  MoreHorizontal,
  Pencil,
  Settings,
  Trash2,
  LogIn,
  LogOut,
  PanelLeftClose,
  PanelLeftOpen,
  Sun,
  Moon,
} from 'lucide-react';
import { useTheme } from 'next-themes';
import { useAppStore } from '@/lib/store';
import { useAuth } from '@/lib/auth-context';
import { useLang } from '@/lib/lang-context';
import type { Conversation } from '@/lib/types';

// ─── Demo mock conversations ──────────────────────────────────────────────────
const now = new Date();
const yesterday = new Date(now);
yesterday.setDate(yesterday.getDate() - 1);
const threeDaysAgo = new Date(now);
threeDaysAgo.setDate(threeDaysAgo.getDate() - 3);
const tenDaysAgo = new Date(now);
tenDaysAgo.setDate(tenDaysAgo.getDate() - 10);

// Mock conversations in Arabic (language-agnostic IDs)
const MOCK_CONVERSATIONS_AR: Conversation[] = [
  { id: 'demo-1', title: 'ماذا قال الله عن الصبر في القرآن؟', messages: [], createdAt: now, updatedAt: now },
  { id: 'demo-2', title: 'ما حكم صلاة الجمعة؟', messages: [], createdAt: yesterday, updatedAt: yesterday },
  { id: 'demo-3', title: 'حديث النبي ﷺ عن الأمانة', messages: [], createdAt: threeDaysAgo, updatedAt: threeDaysAgo },
  { id: 'demo-4', title: 'تفسير سورة الفاتحة', messages: [], createdAt: tenDaysAgo, updatedAt: tenDaysAgo },
];
const MOCK_CONVERSATIONS_EN: Conversation[] = [
  { id: 'demo-1', title: 'What does the Quran say about patience?', messages: [], createdAt: now, updatedAt: now },
  { id: 'demo-2', title: 'Ruling on Friday prayer', messages: [], createdAt: yesterday, updatedAt: yesterday },
  { id: 'demo-3', title: 'Hadith about honesty', messages: [], createdAt: threeDaysAgo, updatedAt: threeDaysAgo },
  { id: 'demo-4', title: 'Tafsir of Surah Al-Fatiha', messages: [], createdAt: tenDaysAgo, updatedAt: tenDaysAgo },
];

// ─── Date grouping ─────────────────────────────────────────────────────────────
function getGroupKey(dateInput: Date | string): string {
  const date = typeof dateInput === 'string' ? new Date(dateInput) : dateInput;
  const diff = Math.floor((new Date().getTime() - date.getTime()) / 86400000);
  if (diff === 0) return 'today';
  if (diff === 1) return 'yesterday';
  if (diff <= 7) return 'last7';
  return 'older';
}

const GROUP_ORDER = ['today', 'yesterday', 'last7', 'older'] as const;

// ─── Conversation item ─────────────────────────────────────────────────────────
function ConvItem({
  conv,
  isActive,
  onSelect,
  renameLabel,
  deleteLabel,
}: {
  conv: Conversation;
  isActive: boolean;
  onSelect: (id: string) => void;
  renameLabel: string;
  deleteLabel: string;
}) {
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <div
      className="group relative flex items-center rounded-lg px-3 py-2 cursor-pointer transition-colors duration-100"
      style={{
        backgroundColor: isActive ? 'var(--surface-3)' : 'transparent',
        color: 'var(--text)',
      }}
      onClick={() => onSelect(conv.id)}
      onMouseLeave={() => setMenuOpen(false)}
    >
      <span className="flex-1 text-sm truncate" style={{ color: isActive ? 'var(--text)' : 'var(--muted)' }}>
        {conv.title}
      </span>

      {/* Context menu trigger */}
      <button
        className="opacity-0 group-hover:opacity-100 p-1 rounded transition-opacity ml-1"
        onClick={(e) => { e.stopPropagation(); setMenuOpen(!menuOpen); }}
        style={{ color: 'var(--muted)' }}
      >
        <MoreHorizontal size={14} />
      </button>

      {menuOpen && (
        <div
          className="absolute top-8 end-2 z-50 rounded-lg border shadow-lg py-1 min-w-[130px]"
          style={{ backgroundColor: 'var(--surface-2)', borderColor: 'var(--border)' }}
        >
          <button
            className="flex items-center gap-2 w-full px-3 py-2 text-sm hover:bg-surface-3 transition-colors"
            style={{ color: 'var(--text)' }}
            onClick={(e) => { e.stopPropagation(); setMenuOpen(false); }}
          >
            <Pencil size={13} /> {renameLabel}
          </button>
          <button
            className="flex items-center gap-2 w-full px-3 py-2 text-sm transition-colors"
            style={{ color: 'var(--danger)' }}
            onClick={(e) => { e.stopPropagation(); setMenuOpen(false); }}
          >
            <Trash2 size={13} /> {deleteLabel}
          </button>
        </div>
      )}
    </div>
  );
}

// ─── Language Toggle ───────────────────────────────────────────────────────────
function LangToggle() {
  const { lang, setLang } = useLang();
  return (
    <div className="lang-toggle">
      <button className={lang === 'ar' ? 'active' : ''} onClick={() => setLang('ar')}>
        AR
      </button>
      <button className={lang === 'en' ? 'active' : ''} onClick={() => setLang('en')}>
        EN
      </button>
    </div>
  );
}

// ─── Main Sidebar ─────────────────────────────────────────────────────────────
export function Sidebar() {
  const router = useRouter();
  const { resolvedTheme, setTheme } = useTheme();
  const { t, lang } = useLang();
  const { user, signOut } = useAuth();
  const sidebarOpen = useAppStore((s) => s.sidebarOpen);
  const setSidebarOpen = useAppStore((s) => s.setSidebarOpen);
  const startNewConversation = useAppStore((s) => s.startNewConversation);
  const currentId = useAppStore((s) => s.currentConversationId);
  const storeConversations = useAppStore((s) => s.conversations);

  // Use store conversations if available, fallback to language-matched demo data
  const conversations = storeConversations.length > 0
    ? storeConversations
    : (lang === 'ar' ? MOCK_CONVERSATIONS_AR : MOCK_CONVERSATIONS_EN);

  // Group conversations
  const groups: Record<string, Conversation[]> = {};
  conversations.forEach((conv) => {
    const key = getGroupKey(conv.updatedAt);
    if (!groups[key]) groups[key] = [];
    groups[key].push(conv);
  });

  const groupLabels: Record<string, string> = {
    today: t.today,
    yesterday: t.yesterday,
    last7: t.last7Days,
    older: t.older,
  };

  const handleSelect = useCallback((id: string) => {
    const isMock = id.startsWith('demo-');
    if (isMock) {
      const mockList = lang === 'ar' ? MOCK_CONVERSATIONS_AR : MOCK_CONVERSATIONS_EN;
      const mockConv = mockList.find((c) => c.id === id);
      if (mockConv) {
        useAppStore.getState().startNewConversation(mockConv.title, mockConv.id);
      }
    } else {
      useAppStore.getState().setCurrentConversation(id);
    }
    router.push(`/chat/${id}`);
  }, [router, lang]);

  const handleNewConversation = useCallback(() => {
    startNewConversation();
    const id = useAppStore.getState().currentConversationId;
    if (id) router.push(`/chat/${id}`);
    else router.push('/chat');
  }, [startNewConversation, router]);

  const toggleCollapse = () => setSidebarOpen(!sidebarOpen);

  const userInitial = user?.user_metadata?.display_name?.[0]?.toUpperCase()
    ?? user?.email?.[0]?.toUpperCase()
    ?? '?';

  // ── Collapsed state (icon-only) ─────────────────────────────────────────────
  if (!sidebarOpen) {
    return (
      <aside
        className="hidden md:flex flex-col items-center py-4 gap-3 border-e h-screen sticky top-0 flex-shrink-0 transition-all duration-250"
        style={{
          width: '64px',
          backgroundColor: 'var(--surface-2)',
          borderColor: 'var(--border)',
        }}
      >
        {/* Expand button */}
        <button
          onClick={toggleCollapse}
          className="p-2 rounded-lg btn btn-ghost"
          title={t.newConversation}
          style={{ color: 'var(--muted)' }}
        >
          <PanelLeftOpen size={20} />
        </button>

        {/* New conversation */}
        <button
          onClick={handleNewConversation}
          className="p-2 rounded-lg btn btn-ghost"
          title={t.newConversation}
          style={{ color: 'var(--primary)' }}
        >
          <MessageSquarePlus size={20} />
        </button>

        <div className="flex-1" />

        {/* Waqf */}
        <Link href="/waqf" className="p-2 rounded-lg btn btn-ghost" title={t.support} style={{ color: '#D97706' }}>
          <span>🕌</span>
        </Link>

        {/* Settings */}
        <Link href="/settings" className="p-2 rounded-lg btn btn-ghost" title={t.settings} style={{ color: 'var(--muted)' }}>
          <Settings size={18} />
        </Link>

        {/* Dark mode */}
        <button
          onClick={() => setTheme(resolvedTheme === 'dark' ? 'light' : 'dark')}
          className="p-2 rounded-lg btn btn-ghost"
          style={{ color: 'var(--muted)' }}
        >
          {resolvedTheme === 'dark' ? <Sun size={16} /> : <Moon size={16} />}
        </button>
      </aside>
    );
  }

  // ── Expanded state ──────────────────────────────────────────────────────────
  return (
    <aside
      className="fixed inset-y-0 start-0 z-30 md:relative md:inset-auto md:z-auto flex flex-col border-e h-screen flex-shrink-0 transition-all duration-250"
      style={{
        width: 'var(--sidebar-width)',
        backgroundColor: 'var(--surface-2)',
        borderColor: 'var(--border)',
      }}
    >
      {/* ── Header ────────────────────────────────────────────── */}
      <div className="flex items-center gap-2 px-4 py-3 border-b" style={{ borderColor: 'var(--border)' }}>
        <span className="text-lg font-bold flex-1" style={{ color: 'var(--primary)' }}>
          🕌 {t.appName}
        </span>
        <button
          onClick={toggleCollapse}
          className="p-1.5 rounded-lg btn btn-ghost hidden md:flex"
          style={{ color: 'var(--muted)' }}
        >
          <PanelLeftClose size={16} />
        </button>
      </div>

      {/* ── New Conversation ───────────────────────────────────── */}
      <div className="px-3 py-3">
        <button
          onClick={handleNewConversation}
          className="btn btn-primary w-full flex items-center gap-2 justify-center text-sm"
        >
          <MessageSquarePlus size={16} />
          {t.newConversation}
        </button>
      </div>

      {/* ── Conversation list / Auth CTA ───────────────────────── */}
      <div className="flex-1 overflow-y-auto px-2 pb-2 space-y-4">
        {user ? (
          <>
            {GROUP_ORDER.map((key) => {
              const group = groups[key];
              if (!group?.length) return null;
              return (
                <div key={key}>
                  <p className="text-xs font-semibold px-3 py-1 uppercase tracking-wide" style={{ color: 'var(--muted)' }}>
                    {groupLabels[key]}
                  </p>
                  {group.map((conv) => (
                    <ConvItem
                      key={conv.id}
                      conv={conv}
                      isActive={conv.id === currentId}
                      onSelect={handleSelect}
                      renameLabel={t.rename}
                      deleteLabel={t.delete}
                    />
                  ))}
                </div>
              );
            })}

            {conversations.length === 0 && (
              <p className="text-sm text-center py-8" style={{ color: 'var(--muted)' }}>
                {t.noConversations}
              </p>
            )}

            {/* Premium subscription promo card */}
            <div className="mx-2 mt-6 p-4 rounded-xl border border-default bg-surface space-y-3 shadow-sm border-s-4 border-s-amber-500">
              <div className="flex items-center gap-2">
                <span className="text-amber-500 text-sm">⭐</span>
                <h4 className="font-semibold text-xs text-text">{t.upgradeTitle}</h4>
              </div>
              <p className="text-[11px] text-muted leading-relaxed">
                {t.upgradeDesc}
              </p>
              <Link
                href="/waqf"
                className="btn btn-primary w-full text-xs justify-center py-1.5 bg-amber-600 hover:bg-amber-700 border-none text-white font-medium"
              >
                {t.upgradeBtn}
              </Link>
            </div>
          </>
        ) : (
          /* Guest registration CTA card */
          <div className="mx-2 my-4 p-4 rounded-xl border border-default bg-surface space-y-4 shadow-sm">
            <div className="flex items-center gap-2">
              <span className="text-lg">🕌</span>
              <h4 className="font-semibold text-xs text-text">{t.guestCtaTitle}</h4>
            </div>
            <p className="text-[11px] text-muted leading-relaxed">
              {t.guestCtaDesc}
            </p>
            <div className="flex flex-col gap-2">
              <Link href="/register" className="btn btn-primary w-full text-xs justify-center py-2 text-white">
                {t.guestCtaRegister}
              </Link>
              <Link href="/login" className="btn btn-outline w-full text-xs justify-center py-2">
                {t.guestCtaLogin}
              </Link>
            </div>
          </div>
        )}
      </div>

      {/* ── Bottom section ─────────────────────────────────────── */}
      <div className="border-t" style={{ borderColor: 'var(--border)' }}>

        {/* Waqf button */}
        <Link
          href="/waqf"
          className="waqf-button flex items-center gap-2 mx-3 my-2 py-2 rounded-lg text-sm transition-colors hover:bg-surface-3"
          style={{ color: '#D97706' }}
        >
          <span>🕌</span>
          <span className="font-medium">{t.support}</span>
        </Link>

        {/* Language toggle + dark mode */}
        <div className="flex items-center justify-between px-4 py-2">
          <LangToggle />
          <button
            onClick={() => setTheme(resolvedTheme === 'dark' ? 'light' : 'dark')}
            className="p-1.5 rounded-lg btn btn-ghost"
            style={{ color: 'var(--muted)' }}
            title={t.darkMode}
          >
            {resolvedTheme === 'dark' ? <Sun size={15} /> : <Moon size={15} />}
          </button>
        </div>

        {/* User section */}
        <div className="flex items-center gap-2 px-3 py-3">
          {user ? (
            <>
              {/* Avatar */}
              <div
                className="w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold flex-shrink-0"
                style={{ backgroundColor: 'var(--primary)', color: '#fff' }}
              >
                {userInitial}
              </div>
              <span className="flex-1 text-sm truncate" style={{ color: 'var(--text)' }}>
                {user.user_metadata?.display_name ?? user.email}
              </span>
              <Link href="/settings" className="p-1.5 rounded btn btn-ghost" title={t.settings} style={{ color: 'var(--muted)' }}>
                <Settings size={15} />
              </Link>
              <button
                onClick={signOut}
                className="p-1.5 rounded btn btn-ghost"
                title={t.logout}
                style={{ color: 'var(--muted)' }}
              >
                <LogOut size={15} />
              </button>
            </>
          ) : (
            <Link href="/login" className="btn btn-outline w-full text-sm flex items-center gap-2 justify-center">
              <LogIn size={15} />
              {t.login}
            </Link>
          )}
        </div>
      </div>
    </aside>
  );
}
