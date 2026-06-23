'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import { Loader2 } from 'lucide-react';
import { getSupabase } from '@/lib/supabase';

export default function RegisterPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      const supabase = getSupabase();
      if (!supabase) { setError('Authentication is not configured yet. Check back soon.'); setLoading(false); return; }
      const { error: signUpError } = await supabase.auth.signUp({
        email,
        password,
        options: {
          data: { display_name: displayName },
        },
      });

      if (signUpError) {
        setError(signUpError.message);
      } else {
        setSuccess(true);
      }
    } catch {
      setError('An unexpected error occurred. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div
      className="min-h-screen flex items-center justify-center px-4"
      style={{ backgroundColor: 'var(--surface)' }}
    >
      <div
        className="w-full max-w-md rounded-2xl border border-default p-8"
        style={{ backgroundColor: 'var(--surface-2)' }}
      >
        {/* Logo */}
        <div className="text-center mb-8">
          <div className="text-4xl mb-3">🕌</div>
          <h1 className="text-2xl font-bold text-text">Create account</h1>
          <p className="text-sm text-muted mt-1">
            Join Qurani AI — your Islamic knowledge companion
          </p>
        </div>

        {/* Success state */}
        {success ? (
          <div
            className="text-center px-4 py-6 rounded-xl border"
            style={{ backgroundColor: 'var(--quran-bg)', borderColor: 'var(--quran)' }}
          >
            <div className="text-3xl mb-3">✉️</div>
            <h2 className="font-semibold text-text mb-2">Check your email</h2>
            <p className="text-sm text-muted">
              We sent a confirmation link to <strong>{email}</strong>. Click it to activate your
              account.
            </p>
            <Link href="/login" className="btn btn-primary mt-4 inline-flex">
              Back to sign in
            </Link>
          </div>
        ) : (
          <>
            {/* Error */}
            {error && (
              <div
                className="mb-4 px-4 py-3 rounded-lg text-sm"
                style={{ backgroundColor: '#FEE2E2', color: '#DC2626' }}
              >
                {error}
              </div>
            )}

            {/* Form */}
            <form onSubmit={handleRegister} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-text mb-1">
                  Display name
                </label>
                <input
                  type="text"
                  value={displayName}
                  onChange={(e) => setDisplayName(e.target.value)}
                  className="input"
                  placeholder="Your name"
                  autoComplete="name"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-text mb-1">
                  Email
                </label>
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                  className="input"
                  placeholder="you@example.com"
                  autoComplete="email"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-text mb-1">
                  Password
                </label>
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                  minLength={8}
                  className="input"
                  placeholder="At least 8 characters"
                  autoComplete="new-password"
                />
              </div>

              <button
                type="submit"
                disabled={loading}
                className="btn btn-primary w-full"
              >
                {loading ? (
                  <>
                    <Loader2 size={15} className="animate-spin" />
                    Creating account…
                  </>
                ) : (
                  'Create account'
                )}
              </button>
            </form>

            <p className="text-center text-sm text-muted mt-6">
              Already have an account?{' '}
              <Link href="/login" className="text-primary hover:underline font-medium">
                Sign in
              </Link>
            </p>
          </>
        )}
      </div>
    </div>
  );
}
