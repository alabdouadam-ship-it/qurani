'use client';

import { useRef, useState, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { Menu, Plus } from 'lucide-react';
import { useAppStore } from '@/lib/store';
import { LandingState } from '@/components/LandingState';
import { ChatInput } from '@/components/ChatInput';

export default function ChatPage() {
  const router = useRouter();
  const inputRef = useRef<{ setValue: (v: string) => void } | null>(null);
  const [prefilled, setPrefilled] = useState('');

  const handleExampleQuestion = useCallback((q: string) => {
    setPrefilled(q);
    // Small timeout to let state update propagate to ChatInput
    setTimeout(() => setPrefilled(''), 50);
  }, []);

  return (
    <div className="flex flex-col h-full">
      {/* Mobile-only header */}
      <header
        className="flex items-center justify-between px-4 h-14 border-b border-default flex-shrink-0 md:hidden animate-fade-in"
        style={{ backgroundColor: 'var(--surface)' }}
      >
        <button
          onClick={() => useAppStore.getState().setSidebarOpen(true)}
          className="p-1.5 rounded-lg btn btn-ghost text-muted"
        >
          <Menu size={18} />
        </button>
        <span className="text-sm font-semibold text-text">🕌 Qurani AI</span>
        <button
          onClick={() => {
            useAppStore.getState().startNewConversation();
            router.push('/chat');
          }}
          className="p-1.5 rounded-lg btn btn-ghost text-muted"
        >
          <Plus size={18} />
        </button>
      </header>

      {/* Landing state fills available space */}
      <div className="flex-1 overflow-hidden">
        <LandingState onQuestion={handleExampleQuestion} />
      </div>

      {/* Input pinned to bottom */}
      <ChatInput />
    </div>
  );
}
