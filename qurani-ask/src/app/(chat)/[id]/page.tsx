'use client';

import React, { useEffect, useRef } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { Share2, Menu, Plus } from 'lucide-react';
import { useAppStore } from '@/lib/store';
import { MessageBubble } from '@/components/MessageBubble';
import { ChatInput } from '@/components/ChatInput';
import { StreamingIndicator } from '@/components/StreamingIndicator';

export default function ConversationPage() {
  const params = useParams();
  const router = useRouter();
  const id = params?.id as string;

  const conversations = useAppStore((s) => s.conversations);
  const currentConversationId = useAppStore((s) => s.currentConversationId);
  const messages = useAppStore((s) => s.messages);
  const setCurrentConversation = useAppStore((s) => s.setCurrentConversation);
  const isStreaming = useAppStore((s) => s.isStreaming);

  const bottomRef = useRef<HTMLDivElement>(null);

  // Load conversation from store
  useEffect(() => {
    if (id && id !== currentConversationId) {
      const conv = conversations.find((c) => c.id === id);
      if (conv) {
        setCurrentConversation(id);
      } else if (conversations.length > 0) {
        // Conversation not found; redirect to /chat
        router.replace('/chat');
      }
    }
  }, [id, conversations, currentConversationId, setCurrentConversation, router]);

  // Auto-scroll to bottom on new messages
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, isStreaming]);

  const conversation = conversations.find((c) => c.id === id);
  const title = conversation?.title ?? 'Conversation';

  return (
    <div className="flex flex-col h-full">
      {/* ── Conversation header ──────────────────────────────────────────────── */}
      <header
        className="flex items-center justify-between px-4 h-14 border-b border-default flex-shrink-0"
        style={{ backgroundColor: 'var(--surface)' }}
      >
        <div className="flex items-center gap-2 overflow-hidden">
          <button
            onClick={() => useAppStore.getState().setSidebarOpen(true)}
            className="md:hidden p-1.5 rounded-lg btn btn-ghost text-muted flex-shrink-0"
          >
            <Menu size={18} />
          </button>
          <h1 className="text-sm font-semibold text-text truncate">{title}</h1>
        </div>

        <div className="flex items-center gap-1 flex-shrink-0">
          <button
            onClick={() => {
              useAppStore.getState().startNewConversation();
              router.push('/chat');
            }}
            className="md:hidden p-1.5 rounded-lg btn btn-ghost text-muted"
            title="New Conversation"
          >
            <Plus size={18} />
          </button>
          <button className="btn btn-ghost px-2 py-1 text-xs flex items-center gap-1 text-muted">
            <Share2 size={14} />
            <span className="hidden sm:inline">Share</span>
          </button>
        </div>
      </header>

      {/* ── Message thread ───────────────────────────────────────────────────── */}
      <div className="flex-1 overflow-y-auto">
        <div className="max-w-3xl mx-auto px-4 py-6 space-y-8">
          {messages.map((message) => (
            <MessageBubble key={message.id} message={message} />
          ))}

          {/* Streaming indicator below messages */}
          {isStreaming && (
            <div className="flex justify-start">
              <StreamingIndicator passageCount={3} />
            </div>
          )}

          {/* Scroll anchor */}
          <div ref={bottomRef} />
        </div>
      </div>

      {/* ── Chat input (pinned bottom) ─────────────────────────────────────── */}
      <ChatInput />
    </div>
  );
}
