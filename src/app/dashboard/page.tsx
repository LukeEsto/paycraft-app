import Link from "next/link";
import { requireCurrentTrade } from "@/lib/auth/current-trade";
import { getCurrentBusinessCustomers } from "@/lib/customers/current-business-customers";
import { formatGbp, getCurrentBusinessQuotes } from "@/lib/quotes/current-business-quotes";

export default async function DashboardPage() {
  const [trade, customers, quotes] = await Promise.all([
    requireCurrentTrade(),
    getCurrentBusinessCustomers(),
    getCurrentBusinessQuotes(),
  ]);

  return (
    <main className="dashboard-shell">
      <header className="dashboard-header">
        <div>
          <div className="brand">PayCraft</div>
          <p className="dashboard-kicker">Jobs</p>
        </div>
        <div className="user-chip" aria-label={`Signed in as ${trade.fullName}`}>{trade.fullName}</div>
      </header>

      <section className="dashboard-content" aria-labelledby="dashboard-title">
        <div>
          <div className="eyebrow">{trade.primaryTrade}</div>
          <h1 id="dashboard-title" className="dashboard-title">Welcome, {trade.tradingName}</h1>
          <p>Your account and business profile are ready.</p>
        </div>

        <section className="customer-section" aria-labelledby="customers-title">
          <div className="section-heading">
            <div>
              <span className="status-badge">{customers.length} {customers.length === 1 ? "customer" : "customers"}</span>
              <h2 id="customers-title">Customers</h2>
            </div>
            <div className="section-actions">
              <Link className="button secondary-button" href="/customers/new">Add customer</Link>
              {customers.length > 0 && <Link className="button" href="/quotes/new">Create quote</Link>}
            </div>
          </div>

          {customers.length === 0 ? (
            <div className="empty-state compact-empty">
              <h3>Create your first customer</h3>
              <p>Add customer contact details before creating a quote.</p>
            </div>
          ) : (
            <ul className="customer-list">
              {customers.map((customer) => (
                <li className="customer-row" key={customer.id}>
                  <div>
                    <strong>{customer.fullName}</strong>
                    <span>{customer.email}</span>
                  </div>
                  <Link className="button secondary-button" href={{ pathname: "/quotes/new", query: { customer: customer.id } }}>Create quote</Link>
                </li>
              ))}
            </ul>
          )}
        </section>

        <section className="customer-section" aria-labelledby="quotes-title">
          <div className="section-heading">
            <div>
              <span className="status-badge">{quotes.length} {quotes.length === 1 ? "quote" : "quotes"}</span>
              <h2 id="quotes-title">Quotes</h2>
            </div>
          </div>

          {quotes.length === 0 ? (
            <div className="empty-state compact-empty">
              <h3>No draft quotes yet</h3>
              <p>Create a customer first, then record the work and price.</p>
            </div>
          ) : (
            <ul className="customer-list">
              {quotes.map((quote) => (
                <li className="customer-row" key={quote.id}>
                  <div>
                    <strong>{quote.jobTitle}</strong>
                    <span>{quote.customerName} · {formatGbp(quote.totalPence)}</span>
                  </div>
                  <span className="status-badge">{quote.status.toLowerCase()}</span>
                </li>
              ))}
            </ul>
          )}
        </section>
      </section>
    </main>
  );
}
