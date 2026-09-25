import Link from "next/link";
import { requireCurrentTrade } from "@/lib/auth/current-trade";
import { getCurrentBusinessCustomers } from "@/lib/customers/current-business-customers";

export default async function DashboardPage() {
  const [trade, customers] = await Promise.all([
    requireCurrentTrade(),
    getCurrentBusinessCustomers(),
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
            <Link className="button" href="/customers/new">Add customer</Link>
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
                  <button className="button secondary-button" type="button" disabled>Create quote</button>
                </li>
              ))}
            </ul>
          )}
        </section>
      </section>
    </main>
  );
}
