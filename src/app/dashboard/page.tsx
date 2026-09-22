import { requireCurrentTrade } from "@/lib/auth/current-trade";

export default async function DashboardPage() {
  const trade = await requireCurrentTrade();

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

        <div className="empty-state">
          <span className="status-badge">No jobs yet</span>
          <h2>Create your first customer next</h2>
          <p>The next feasibility task will add customer creation without expanding into the full MVP.</p>
          <button className="button" type="button" disabled>Create Quote</button>
        </div>
      </section>
    </main>
  );
}
