import { RegistrationForm } from "./registration-form";

export default function RegisterPage() {
  return (
    <main className="shell align-start">
      <section className="card registration-card" aria-labelledby="register-title">
        <div className="brand">PayCraft</div>
        <div className="eyebrow">Tradesperson account</div>
        <h1 id="register-title" className="form-title">Create your account</h1>
        <p>Set up your basic business profile. You can complete additional details later.</p>
        <RegistrationForm />
      </section>
    </main>
  );
}
