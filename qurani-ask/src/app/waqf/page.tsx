'use client';

import Link from 'next/link';
import { useState } from 'react';
import { ArrowLeft, Server, Sprout, Heart, Info } from 'lucide-react';
import { useAuth } from '@/lib/auth-context';

const REASON_CARDS = [
  {
    icon: Server,
    title: 'Keep it running',
    titleAr: 'استمرار الخدمة',
    description:
      'Servers, AI APIs, and storage have real costs. Your support keeps Qurani AI alive and free for all.',
  },
  {
    icon: Sprout,
    title: "Build what's next",
    titleAr: 'بناء المستقبل',
    description:
      'More tafsir books, better Arabic AI, multilingual interface, and mobile apps. Every feature costs real time.',
  },
  {
    icon: Heart,
    title: 'Give others access',
    titleAr: 'منح الوصول للآخرين',
    description:
      'Your support funds free accounts for students, imams, and those in need. Admin reviews and approves requests.',
  },
];

const CONTRIBUTION_OPTIONS = [
  {
    id: 'a',
    label: 'One-time · صدقة',
    sublabel: 'Any amount — a single act of support',
    amount: null,
    placeholder: true,
  },
  {
    id: 'b',
    label: 'Monthly · وقف شهري',
    sublabel: 'Ongoing support — keeps the lights on',
    amount: null,
    placeholder: true,
    recommended: true,
  },
  {
    id: 'c',
    label: 'Sponsor others · كفالة',
    sublabel: 'Fund free accounts for those who cannot pay',
    amount: null,
    placeholder: true,
  },
];

export default function WaqfPage() {
  const { user } = useAuth();
  const [selectedOption, setSelectedOption] = useState<string | null>(null);
  const [note, setNote] = useState('');

  return (
    <div
      className="min-h-screen"
      style={{ backgroundColor: 'var(--surface)', color: 'var(--text)' }}
    >
      {/* Nav bar */}
      <nav
        className="sticky top-0 z-10 flex items-center gap-3 px-6 py-4 border-b"
        style={{
          backgroundColor: 'var(--surface-2)',
          borderColor: 'var(--border)',
        }}
      >
        <Link
          href="/chat"
          className="flex items-center gap-2 text-sm btn btn-ghost"
          style={{ color: 'var(--muted)' }}
        >
          <ArrowLeft size={16} />
          Back to Qurani AI
        </Link>
        <div className="flex-1" />
        <span className="text-sm font-semibold" style={{ color: 'var(--primary)' }}>
          🕌 وقف · Waqf
        </span>
      </nav>

      <div className="max-w-3xl mx-auto px-6 py-12 space-y-16">

        {/* ── Hero ──────────────────────────────────────────── */}
        <section className="text-center space-y-6">
          <p
            className="font-arabic text-2xl"
            style={{ color: 'var(--muted)' }}
            dir="rtl"
          >
            بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ
          </p>

          <h1 className="text-4xl font-bold" style={{ color: 'var(--primary)' }}>
            وقف · Support Qurani AI
          </h1>

          <blockquote
            className="card max-w-xl mx-auto text-left space-y-3"
            style={{ borderLeft: '4px solid var(--primary)' }}
          >
            <p className="text-base leading-relaxed" style={{ color: 'var(--text)' }}>
              &ldquo;When a person dies, his deeds come to an end except for three:
              Sadaqah Jariyah (ongoing charity), beneficial knowledge, or a
              righteous child who prays for him.&rdquo;
            </p>
            <footer className="text-sm" style={{ color: 'var(--muted)' }}>
              — Sahih Muslim #1631
            </footer>
          </blockquote>

          <p className="text-base max-w-xl mx-auto leading-relaxed" style={{ color: 'var(--muted)' }}>
            This project is built as an act of service to the Muslim community.
            Your support — in any form — is a contribution to spreading
            beneficial knowledge.
          </p>
        </section>

        {/* ── Why Support ────────────────────────────────────── */}
        <section className="space-y-6">
          <h2 className="text-xl font-semibold text-center">Why support this project?</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {REASON_CARDS.map((card) => {
              const Icon = card.icon;
              return (
                <div key={card.title} className="card card-hover space-y-3">
                  <div
                    className="w-10 h-10 rounded-lg flex items-center justify-center"
                    style={{ backgroundColor: 'var(--surface-3)' }}
                  >
                    <Icon size={20} style={{ color: 'var(--primary)' }} />
                  </div>
                  <div>
                    <h3 className="font-semibold text-sm">{card.title}</h3>
                    <p
                      className="text-xs font-arabic mt-0.5"
                      style={{ color: 'var(--muted)', fontSize: '0.8rem' }}
                      dir="rtl"
                    >
                      {card.titleAr}
                    </p>
                  </div>
                  <p className="text-sm leading-relaxed" style={{ color: 'var(--muted)' }}>
                    {card.description}
                  </p>
                </div>
              );
            })}
          </div>
        </section>

        {/* ── Contribution Options ───────────────────────────── */}
        <section className="space-y-6">
          <h2 className="text-xl font-semibold">Choose how you would like to contribute</h2>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            {CONTRIBUTION_OPTIONS.map((opt) => (
              <button
                key={opt.id}
                onClick={() => setSelectedOption(opt.id)}
                className="card card-hover text-left space-y-2 transition-all duration-150 cursor-pointer relative"
                style={{
                  border: selectedOption === opt.id
                    ? '2px solid var(--primary)'
                    : '1px solid var(--border)',
                  backgroundColor: selectedOption === opt.id
                    ? 'color-mix(in srgb, var(--primary) 6%, var(--surface-2))'
                    : 'var(--surface-2)',
                }}
              >
                {opt.recommended && (
                  <span
                    className="absolute top-2 right-2 badge"
                    style={{ backgroundColor: 'var(--primary)', color: '#fff' }}
                  >
                    Recommended
                  </span>
                )}
                <p className="font-semibold text-sm pr-20">{opt.label}</p>
                <p className="text-xs" style={{ color: 'var(--muted)' }}>
                  {opt.sublabel}
                </p>
                <p
                  className="text-xs mt-2 italic"
                  style={{ color: 'var(--muted)' }}
                >
                  Amount &amp; method — coming soon
                </p>
              </button>
            ))}
          </div>

          {/* Note field */}
          <div className="space-y-2">
            <label className="text-sm font-medium flex items-center gap-2">
              ✏️ Leave a note{' '}
              <span className="text-xs font-normal" style={{ color: 'var(--muted)' }}>
                (optional)
              </span>
            </label>
            <textarea
              value={note}
              onChange={(e) => setNote(e.target.value)}
              rows={3}
              className="input textarea"
              placeholder="You can write a message to the developer, a dua, or anything you would like to share..."
            />
          </div>

          {/* Payment button */}
          <div className="flex items-center gap-3">
            <button
              disabled
              className="btn btn-primary"
              title="Payment method coming soon — جزاك الله خيراً"
            >
              Proceed to payment →
            </button>
            <span className="text-xs flex items-center gap-1" style={{ color: 'var(--muted)' }}>
              <Info size={12} />
              Payment method coming soon — جزاك الله خيراً
            </span>
          </div>
        </section>

        {/* ── Sponsor Others ─────────────────────────────────── */}
        <section
          className="card space-y-4"
          style={{ borderLeft: '4px solid var(--tafsir)' }}
        >
          <div className="flex items-start gap-3">
            <span className="text-2xl mt-0.5">🤲</span>
            <div className="space-y-2">
              <h2 className="text-lg font-semibold">
                Pay it forward — Sponsor free access for others
              </h2>
              <p className="text-sm leading-relaxed" style={{ color: 'var(--muted)' }}>
                Your contribution goes into the Waqf pool. The admin uses this
                pool to approve free account applications from students, imams,
                and those in need.
              </p>
              <p className="text-sm leading-relaxed" style={{ color: 'var(--muted)' }}>
                You will receive confirmation of how many accounts your
                contribution has helped fund.
              </p>
              <p className="text-xs italic" style={{ color: 'var(--muted)' }}>
                No gift codes or direct targeting — the contributor pays into the
                pool and trusts the custodian, true to the Waqf concept.
              </p>
            </div>
          </div>
          <button disabled className="btn btn-outline text-sm" title="Coming soon">
            Contribute to the Waqf pool →
          </button>
        </section>

        {/* ── Apply for Free Account ─────────────────────────── */}
        <section
          className="card space-y-4"
          style={{ borderLeft: '4px solid var(--border)' }}
        >
          <div className="space-y-2">
            <h2 className="text-lg font-semibold">📩 Cannot afford a subscription?</h2>
            <p className="text-sm leading-relaxed" style={{ color: 'var(--muted)' }}>
              Apply for a Waqf-funded free account. Applications are reviewed by
              the admin and approved based on available funds.{' '}
              <strong>There is no shame in applying</strong> — this is exactly
              what the Waqf exists for.
            </p>
          </div>
          {user ? (
            <Link href="/waqf/apply" className="btn btn-outline inline-flex text-sm">
              Apply for free access →
            </Link>
          ) : (
            <div className="flex items-center gap-3">
              <Link href="/login" className="btn btn-outline text-sm">
                Sign in to apply
              </Link>
              <span className="text-xs" style={{ color: 'var(--muted)' }}>
                A free account is required to submit an application
              </span>
            </div>
          )}
        </section>

        {/* ── Footer note ─────────────────────────────────────── */}
        <footer className="text-center text-xs space-y-1 pb-8" style={{ color: 'var(--muted)' }}>
          <p>جزاك الله خيراً — May Allah reward you for your support.</p>
          <p>All notes and contributions are stored privately and never shared publicly.</p>
        </footer>
      </div>
    </div>
  );
}
