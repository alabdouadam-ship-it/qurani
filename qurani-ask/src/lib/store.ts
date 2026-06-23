import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import type { AiMessage, Conversation, SourceSelection } from './types';
import { DEFAULT_SOURCE_SELECTION } from './constants';

// ─── State shape ──────────────────────────────────────────────────────────────
interface AppState {
  // Conversations
  conversations: Conversation[];
  currentConversationId: string | null;
  messages: AiMessage[];

  // UI
  sidebarOpen: boolean;
  sourcePanelOpen: boolean;
  isStreaming: boolean;

  // Sources
  sourceSelection: SourceSelection;

  // Guest usage
  queryCountToday: number;

  // ─── Actions ────────────────────────────────────────────────────────────────
  setSidebarOpen: (open: boolean) => void;
  setSourcePanelOpen: (open: boolean) => void;
  addMessage: (message: AiMessage) => void;
  updateLastMessage: (partial: Partial<AiMessage>) => void;
  setStreaming: (streaming: boolean) => void;
  setSourceSelection: (selection: SourceSelection) => void;
  loadConversations: (conversations: Conversation[]) => void;
  startNewConversation: (title?: string, customId?: string) => void;
  setCurrentConversation: (id: string) => void;
  incrementQueryCount: () => void;
}

// ─── Store ─────────────────────────────────────────────────────────────────────
export const useAppStore = create<AppState>()(
  persist(
    (set, get) => ({
      conversations: [],
      currentConversationId: null,
      messages: [],
      sidebarOpen: true,
      sourcePanelOpen: false,
      isStreaming: false,
      sourceSelection: DEFAULT_SOURCE_SELECTION,
      queryCountToday: 0,

      setSidebarOpen: (open) => set({ sidebarOpen: open }),

      setSourcePanelOpen: (open) => set({ sourcePanelOpen: open }),

      addMessage: (message) => {
        const { messages, conversations, currentConversationId } = get();
        const newMessages = [...messages, message];
        set({ messages: newMessages });

        // Update conversation in list or create new one
        if (currentConversationId) {
          const updatedConversations = conversations.map((c) =>
            c.id === currentConversationId
              ? { ...c, messages: newMessages, updatedAt: new Date() }
              : c,
          );
          set({ conversations: updatedConversations });
        }
      },

      updateLastMessage: (partial) => {
        const { messages, conversations, currentConversationId } = get();
        if (messages.length === 0) return;

        const newMessages = messages.map((m, i) =>
          i === messages.length - 1 ? { ...m, ...partial } : m,
        );
        set({ messages: newMessages });

        if (currentConversationId) {
          const updatedConversations = conversations.map((c) =>
            c.id === currentConversationId
              ? { ...c, messages: newMessages, updatedAt: new Date() }
              : c,
          );
          set({ conversations: updatedConversations });
        }
      },

      setStreaming: (streaming) => set({ isStreaming: streaming }),

      setSourceSelection: (selection) => set({ sourceSelection: selection }),

      loadConversations: (conversations) => set({ conversations }),

      startNewConversation: (title, customId) => {
        const id = customId || crypto.randomUUID();
        const now = new Date();
        const { conversations } = get();

        // If it already exists, just make it the active conversation
        const existing = conversations.find((c) => c.id === id);
        if (existing) {
          set({
            currentConversationId: id,
            messages: existing.messages,
          });
          return;
        }

        const newConv: Conversation = {
          id,
          title: title || 'New Conversation',
          messages: [],
          createdAt: now,
          updatedAt: now,
        };
        set({
          conversations: [newConv, ...conversations],
          currentConversationId: id,
          messages: [],
        });
      },

      setCurrentConversation: (id) => {
        const { conversations } = get();
        const conv = conversations.find((c) => c.id === id);
        if (conv) {
          set({
            currentConversationId: id,
            messages: conv.messages,
          });
        }
      },

      incrementQueryCount: () =>
        set((state) => ({ queryCountToday: state.queryCountToday + 1 })),
    }),
    {
      name: 'qurani-ask-store',
      partialize: (state) => ({
        sourceSelection: state.sourceSelection,
        sidebarOpen: state.sidebarOpen,
        queryCountToday: state.queryCountToday,
        conversations: state.conversations,
        currentConversationId: state.currentConversationId,
        messages: state.messages,
      }),
    },
  ),
);
