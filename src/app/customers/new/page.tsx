import Link from "next/link";
import { requireCurrentTrade } from "@/lib/auth/current-trade";
import { CustomerForm } from "./customer-form";

export default async function NewCustomerPage() {
  await requireCurrentTrade();

  return (
    <main className="shell align-start">
      <section className="card registration-card" aria-labelledby="customer-title">
        <Link className="back-link" href="/dashboard">← Back to Jobs</Link>
        <div className="eyebrow">New customer</div>
        <h1 id="customer-title" className="form-title">Add customer details</h1>
        <p>Add the person who will receive and review your quote.</p>
        <CustomerForm />
      </section>
    </main>
  );
}
