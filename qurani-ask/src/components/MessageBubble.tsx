'use client';

import React from 'react';
import type { AiMessage } from '@/lib/types';
import { AiAnswer } from './AiAnswer';

// ─── User bubble ──────────────────────────────────────────────────────────────
function UserBubble({ message }: { message: AiMessage }) {
  const time = message.createdAt
    ? new Intl.DateTimeFormat('en', { hour: '2-digit', minute: '2-digit' }).format(
        message.createdAt instanceof Date ? message.createdAt : new Date(message.createdAt),
      )
    : '';

  return (
    <div className="flex justify-end">
      <div className="group relative max-w-[80%] sm:max-w-[65%]">
        <div
          className="px-4 py-3 rounded-2xl rounded-tr-sm text-sm leading-relaxed break-words"
          style={{
            backgroundColor: 'var(--primary)',
            color: '#ffffff',
          }}
        >
          {message.content}
        </div>
        {time && (
          <span className="absolute -bottom-5 right-0 text-[10px] text-muted opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap">
            {time}
          </span>
        )}
      </div>
    </div>
  );
}

// ─── MessageBubble ─────────────────────────────────────────────────────────────
export function MessageBubble({ message }: { message: AiMessage }) {
  if (message.role === 'user') {
    return <UserBubble message={message} />;
  }

  return (
    <div className="flex justify-start">
      <div className="w-full max-w-3xl">
        <AiAnswer message={message} />
      </div>
    </div>
  );
}
