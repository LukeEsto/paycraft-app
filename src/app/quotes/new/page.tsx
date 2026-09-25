import Link from "next/link";
import { redirect } from "next/navigation";
import { getCurrentBusinessCustomers } from "@/lib/customers/current-business-customers";
import { QuoteForm } from "./quote-form";

interface NewQuotePageProps {
  searchParams: Promise<{ customer?: string | string[] }>;
}

export default async function NewQuotePage({ searchParams }: NewQuotePageProps) {
  const [customers, query] = await Promise.all([getCurrentBusinessCustomers(), searchParams]);
  if (customers.length === 0) redirect("/customers/new");
  const selectedCustomerId = typeof query.customer === "string" && customers.some((customer) => customer.id === query.customer)
    ? query.customer
    : undefined;

  return (
    <main className="shell align-start">
      <section className="card quote-card" aria-labelledby="quote-title">
        <Link className="back-link" href="/dashboard">← Back to Jobs</Link>
        <div className="eyebrow">Draft quote</div>
        <h1 id="quote-title" className="form-title">Create a quote</h1>
        <p>Record the agreed work and pricing. Customer delivery is added in the next feasibility package.</p>
        <QuoteForm customers={customers} selectedCustomerId={selectedCustomerId} />
      </section>
    </main>
  );
}
