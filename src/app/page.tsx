export default function Home() {
  return (
    <main className="shell">
      <section className="card" aria-labelledby="title">
        <div className="brand">PayCraft</div>
        <div className="eyebrow">Phase 1 feasibility trial</div>
        <h1 id="title">Clear quotes. Clear decisions.</h1>
        <p>
          This staging shell will prove the secure journey from tradesperson registration to
          customer quote acceptance and an auditable admin record.
        </p>
        <div className="notice">
          Payments are simulated. PayCraft does not receive, hold, safeguard or release funds in this trial.
        </div>
        <p><a className="button" href="/register">Create tradesperson account</a></p>
      </section>
    </main>
  );
}
