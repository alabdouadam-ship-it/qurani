'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { ArrowLeft, CheckCircle2 } from 'lucide-react';
import { useAuth } from '@/lib/auth-context';
import { getSupabase } from '@/lib/supabase';

const COUNTRIES = [
  '', 'Algeria', 'Bahrain', 'Bangladesh', 'Egypt', 'France', 'Germany',
  'Indonesia', 'Iran', 'Iraq', 'Jordan', 'Kuwait', 'Lebanon', 'Libya',
  'Malaysia', 'Mauritania', 'Morocco', 'Nigeria', 'Oman', 'Pakistan',
  'Palestine', 'Qatar', 'Saudi Arabia', 'Senegal', 'Somalia', 'Sudan',
  'Syria', 'Tunisia', 'Turkey', 'UAE', 'United Kingdom', 'United States',
  'Yemen', 'Other',
];

export default function WaqfApplyPage() {
  const { user, loading } = useAuth();
  const router = useRouter();

  const [reason, setReason] = useState('');
  const [country, setCountry] = useState('');
  const [agreed, setAgreed] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [error, setError] = useState('');

  // Redirect to login if not authenticated
  useEffect(() => {
    if (!loading && !user) {
      router.push('/login?redirect=/waqf/apply');
    }
  }, [user, loading, router]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!agreed || !user) return;

    setSubmitting(true);
    setError('');

    try {
      const supabase = getSupabase();
      if (!supabase) { setError('The Waqf system is not yet connected. Please try again later or contact support.'); setSubmitting(false); return; }
      const { error: insertError } = await supabase
        .from('waqf_applications')
        .insert({
          user_id: user.id,
          reason: reason.trim() || null,
          country: country || null,
          status: 'pending',
        });

      if (insertError) {
        // If table doesn't exist yet, show a graceful message
        if (insertError.code === '42P01') {
          setError(
            'The Waqf system is being set up. Please try again soon, or contact support.'
          );
        } else {
          setError(insertError.message);
        }
        setSubmitting(false);
        return;
      }

      setSubmitted(true);
    } catch {
      setError('Something went wrong. Please try again.');
      setSubmitting(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center" style={{ backgroundColor: 'var(--surface)' }}>
        <div className="w-8 h-8 rounded-full border-2 border-t-transparent animate-spin" style={{ borderColor: 'var(--primary)' }} />
      </div>
    );
  }

  if (!user) return null; // Redirecting

  if (submitted) {
    return (
      <div className="min-h-screen flex items-center justify-center px-6" style={{ backgroundColor: 'var(--surface)' }}>
        <div className="max-w-md w-full card text-center space-y-6 py-12">
          <CheckCircle2 size={56} className="mx-auto" style={{ color: 'var(--primary)' }} />
          <div className="space-y-3">
            <p className="font-arabic text-2xl" dir="rtl" style={{ color: 'var(--primary)' }}>
              جزاك الله خيراً
            </p>
            <h1 className="text-xl font-semibold">Application Submitted</h1>
            <p className="text-sm leading-relaxed" style={{ color: 'var(--muted)' }}>
              Thank you for your application. We will review it personally and
              respond to your email within a few days. There is no shame in
              applying — this is exactly what the Waqf exists for.
            </p>
          </div>
          <Link href="/chat" className="btn btn-primary mx-auto">
            Return to Qurani AI
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen" style={{ backgroundColor: 'var(--surface)', color: 'var(--text)' }}>
      {/* Nav */}
      <nav
        className="sticky top-0 z-10 flex items-center gap-3 px-6 py-4 border-b"
        style={{ backgroundColor: 'var(--surface-2)', borderColor: 'var(--border)' }}
      >
        <Link href="/waqf" className="flex items-center gap-2 text-sm btn btn-ghost" style={{ color: 'var(--muted)' }}>
          <ArrowLeft size={16} />
          Back
        </Link>
        <span className="text-sm font-semibold" style={{ color: 'var(--primary)' }}>
          Apply for Waqf-funded Access
        </span>
      </nav>

      <div className="max-w-xl mx-auto px-6 py-12">
        <div className="space-y-8">
          {/* Header */}
          <div className="space-y-3">
            <h1 className="text-2xl font-bold">Apply for Free Access</h1>
            <p className="text-sm leading-relaxed" style={{ color: 'var(--muted)' }}>
              We review applications personally and respond within a few days.{' '}
              <strong>There is no means test — we take your word for it.</strong>
            </p>
            <div
              className="card text-sm"
              style={{ borderLeft: '3px solid var(--primary)', backgroundColor: 'color-mix(in srgb, var(--primary) 5%, var(--surface-2))' }}
            >
              <p>
                This access is funded by community contributions (Waqf). If you
                receive approval, you will have unlimited queries without any
                payment. In return, we only ask that you use the service
                responsibly.
              </p>
            </div>
          </div>

          {/* Form */}
          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Reason */}
            <div className="space-y-2">
              <label className="text-sm font-medium" htmlFor="reason">
                Why are you applying?{' '}
                <span className="font-normal" style={{ color: 'var(--muted)' }}>
                  (optional — helps us understand need)
                </span>
              </label>
              <textarea
                id="reason"
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                rows={4}
                maxLength={500}
                className="input textarea"
                placeholder="e.g. student, limited income, imam without resources, seeking Islamic knowledge in a remote area..."
              />
              <p className="text-xs text-right" style={{ color: 'var(--muted)' }}>
                {reason.length}/500
              </p>
            </div>

            {/* Country */}
            <div className="space-y-2">
              <label className="text-sm font-medium" htmlFor="country">
                Country{' '}
                <span className="font-normal" style={{ color: 'var(--muted)' }}>
                  (optional — helps us understand reach)
                </span>
              </label>
              <select
                id="country"
                value={country}
                onChange={(e) => setCountry(e.target.value)}
                className="input"
                style={{ cursor: 'pointer' }}
              >
                {COUNTRIES.map((c) => (
                  <option key={c} value={c}>
                    {c || '— Select your country —'}
                  </option>
                ))}
              </select>
            </div>

            {/* Agreement */}
            <label className="flex items-start gap-3 cursor-pointer group">
              <input
                type="checkbox"
                checked={agreed}
                onChange={(e) => setAgreed(e.target.checked)}
                className="mt-1 w-4 h-4 rounded accent-[var(--primary)] cursor-pointer"
                required
              />
              <span className="text-sm leading-relaxed" style={{ color: 'var(--muted)' }}>
                I understand this is funded by community contributions (Waqf) and
                I will use the service responsibly, not abusing the free access
                granted to me.
              </span>
            </label>

            {/* Error */}
            {error && (
              <p className="text-sm p-3 rounded-lg" style={{ backgroundColor: 'color-mix(in srgb, var(--danger) 10%, var(--surface-2))', color: 'var(--danger)' }}>
                {error}
              </p>
            )}

            {/* Submit */}
            <div className="flex justify-end pt-2">
              <button
                type="submit"
                disabled={!agreed || submitting}
                className="btn btn-primary px-8 py-2.5 text-sm font-semibold"
              >
                {submitting ? 'Submitting...' : 'Submit application'}
              </button>
            </div>

            <p className="text-center text-xs" style={{ color: 'var(--muted)' }}>
              جزاك الله خيراً — May Allah reward you for seeking knowledge.
            </p>
          </form>
        </div>
      </div>
    </div>
  );
}
