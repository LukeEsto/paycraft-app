import type { Metadata } from "next";
import { formatGbp } from "@/lib/quotes/current-business-quotes";
import { resolveInviteToken } from "@/lib/invites/resolve-invite";
import { EmailVerification } from "./email-verification";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Review quote | PayCraft",
  robots: { index: false, follow: false },
};

interface CustomerQuotePageProps {
  params: Promise<{ token: string }>;
}

export default async function CustomerQuotePage({ params }: CustomerQuotePageProps) {
  const { token } = await params;
  const quote = await resolveInviteToken(token);

  if (!quote) {
    return (
      <main className="shell">
        <section className="card" aria-labelledby="invalid-link-title">
          <div className="brand">PayCraft</div>
          <h1 id="invalid-link-title" className="form-title">This quote link is unavailable</h1>
          <p>The link may be invalid, expired, revoked or already used. Ask the tradesperson for a new link.</p>
        </section>
      </main>
    );
  }

  return (
    <main className="shell align-start">
      <article className="card quote-card" aria-labelledby="public-quote-title">
        <div className="brand">PayCraft</div>
        <div className="eyebrow">Quote from {quote.trading_name}</div>
        <h1 id="public-quote-title" className="form-title">{quote.job_title}</h1>
        <p>Prepared for {quote.customer_name}</p>

        <section className="quote-scope" aria-labelledby="scope-title">
          <h2 id="scope-title">Scope of work</h2>
          <p>{quote.scope}</p>
        </section>

        <section aria-labelledby="items-title">
          <h2 id="items-title">Quote items</h2>
          <ul className="quote-items-list">
            {quote.items.map((item, index) => (
              <li key={`${item.description}-${index}`}>
                <div><strong>{item.description}</strong><span>{item.quantity} × {formatGbp(item.unit_amount_pence)}</span></div>
                <strong>{formatGbp(item.line_total_pence)}</strong>
              </li>
            ))}
          </ul>
          <div className="quote-total"><span>Total</span><strong>{formatGbp(quote.total_pence)}</strong></div>
        </section>

        <EmailVerification token={token} alreadyVerified={quote.email_verified} />
        <div className="notice">This feasibility page remains view-only. Verification does not accept the quote or create a payment.</div>
      </article>
    </main>
  );
}
