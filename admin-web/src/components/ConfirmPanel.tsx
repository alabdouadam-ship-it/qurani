"use client";

import { useUi } from "@/lib/ui-context";

/**
 * Inline confirmation for a destructive action.
 *
 * Replaces `window.confirm`, which had three problems here: it cannot show WHAT
 * is about to be deleted (so "Delete this item?" was the entire prompt), it is
 * dismissed by the same reflex Enter/Escape that people use to get through
 * dialogs, and it cannot offer a safer alternative — which reciters need, since
 * disabling one is almost always the right move and deleting it orphans the
 * `code` that readers have saved on their devices.
 *
 * Renders in place of the list rather than over it, so the destructive button is
 * never one stray click away from where the row used to be.
 */
export function ConfirmPanel({
  title,
  subject,
  warning,
  confirmLabel,
  altLabel,
  onConfirm,
  onAlt,
  onCancel,
  busy = false,
  error,
}: {
  /** What is being asked, e.g. "Delete this item?". */
  title: string;
  /** The specific thing at stake — a news title, a reciter name. Shown
   *  prominently so the action cannot be confused for a different row. */
  subject: string;
  /** Consequence the operator may not have considered. */
  warning?: string;
  confirmLabel: string;
  /** Optional safer path, e.g. "Disable instead". Omitted when there isn't one. */
  altLabel?: string;
  onConfirm: () => void;
  onAlt?: () => void;
  onCancel: () => void;
  busy?: boolean;
  error?: string | null;
}) {
  const { t } = useUi();
  return (
    <div
      className="card p-4 flex flex-col gap-3"
      style={{ borderColor: "var(--danger)" }}
      role="alertdialog"
      aria-label={title}
    >
      <h2 className="font-bold">{title}</h2>
      <p className="text-sm font-semibold">{subject}</p>
      {warning && <p className="muted text-sm">{warning}</p>}
      {error && <p role="alert" style={{ color: "var(--danger)" }}>{error}</p>}
      <div className="flex flex-wrap gap-2">
        {/* The safe option comes first and keeps the primary styling: the
            destructive one should be the deliberate choice, not the default. */}
        {altLabel && onAlt && (
          <button
            type="button"
            className="btn btn-primary"
            onClick={onAlt}
            disabled={busy}
          >
            {altLabel}
          </button>
        )}
        <button
          type="button"
          className="btn btn-danger"
          onClick={onConfirm}
          disabled={busy}
        >
          {confirmLabel}
        </button>
        <button
          type="button"
          className="btn btn-ghost"
          onClick={onCancel}
          disabled={busy}
        >
          {t.cancel}
        </button>
      </div>
    </div>
  );
}
