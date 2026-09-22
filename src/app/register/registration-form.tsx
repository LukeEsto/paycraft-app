"use client";

import { useActionState } from "react";
import { registerTrade, type RegistrationState } from "./actions";

const initialState: RegistrationState = {};

function ErrorText({ errors }: { errors?: string[] }) {
  if (!errors?.length) return null;
  return <p className="field-error">{errors[0]}</p>;
}

export function RegistrationForm() {
  const [state, action, pending] = useActionState(registerTrade, initialState);

  return (
    <form action={action} className="form-stack" noValidate>
      <div className="field">
        <label htmlFor="fullName">Your name</label>
        <input id="fullName" name="fullName" autoComplete="name" required />
        <ErrorText errors={state.errors?.fullName} />
      </div>

      <div className="field">
        <label htmlFor="tradingName">Company or trading name</label>
        <input id="tradingName" name="tradingName" autoComplete="organization" required />
        <ErrorText errors={state.errors?.tradingName} />
      </div>

      <div className="form-grid">
        <div className="field">
          <label htmlFor="primaryTrade">Primary trade</label>
          <select id="primaryTrade" name="primaryTrade" defaultValue="" required>
            <option value="" disabled>Select trade</option>
            <option>Builder</option>
            <option>Carpenter</option>
            <option>Decorator</option>
            <option>Electrician</option>
            <option>Gas Engineer</option>
            <option>Plumber</option>
            <option>Roofer</option>
            <option value="Other">Other</option>
          </select>
          <ErrorText errors={state.errors?.primaryTrade} />
        </div>

        <div className="field">
          <label htmlFor="businessType">Business type</label>
          <select id="businessType" name="businessType" defaultValue="" required>
            <option value="" disabled>Select type</option>
            <option value="LIMITED_COMPANY">Limited company</option>
            <option value="SOLE_TRADER">Sole trader</option>
            <option value="PARTNERSHIP">Partnership</option>
            <option value="OTHER">Other</option>
          </select>
          <ErrorText errors={state.errors?.businessType} />
        </div>
      </div>

      <div className="field">
        <label htmlFor="email">Email address</label>
        <input id="email" name="email" type="email" autoComplete="email" required />
        <ErrorText errors={state.errors?.email} />
      </div>

      <div className="field">
        <label htmlFor="phone">Phone number</label>
        <input id="phone" name="phone" type="tel" autoComplete="tel" required />
        <ErrorText errors={state.errors?.phone} />
      </div>

      <div className="field">
        <label htmlFor="password">Password</label>
        <input id="password" name="password" type="password" autoComplete="new-password" required />
        <p className="field-hint">At least 12 characters with upper and lowercase letters, a number and a symbol.</p>
        <ErrorText errors={state.errors?.password} />
      </div>

      <label className="check-row">
        <input name="termsAccepted" type="checkbox" />
        <span>I accept the PayCraft Terms for this feasibility trial.</span>
      </label>
      <ErrorText errors={state.errors?.termsAccepted} />

      <label className="check-row">
        <input name="privacyAccepted" type="checkbox" />
        <span>I have read and accept the PayCraft Privacy Notice.</span>
      </label>
      <ErrorText errors={state.errors?.privacyAccepted} />

      {state.message && <div className="form-message" role="alert">{state.message}</div>}

      <button className="button" disabled={pending} type="submit">
        {pending ? "Creating account…" : "Create tradesperson account"}
      </button>
    </form>
  );
}
