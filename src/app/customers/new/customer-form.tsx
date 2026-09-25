"use client";

import { useActionState } from "react";
import { createCustomer, type CustomerState } from "./actions";

const initialState: CustomerState = {};

function ErrorText({ errors }: { errors?: string[] }) {
  if (!errors?.length) return null;
  return <p className="field-error">{errors[0]}</p>;
}

export function CustomerForm() {
  const [state, action, pending] = useActionState(createCustomer, initialState);

  return (
    <form action={action} className="form-stack" noValidate>
      <div className="field">
        <label htmlFor="fullName">Customer name</label>
        <input id="fullName" name="fullName" autoComplete="name" required />
        <ErrorText errors={state.errors?.fullName} />
      </div>

      <div className="field">
        <label htmlFor="email">Email address</label>
        <input id="email" name="email" type="email" autoComplete="email" required />
        <ErrorText errors={state.errors?.email} />
      </div>

      <div className="field">
        <label htmlFor="phone">Phone number <span className="optional-label">Optional</span></label>
        <input id="phone" name="phone" type="tel" autoComplete="tel" />
        <ErrorText errors={state.errors?.phone} />
      </div>

      {state.message && <div className="form-message" role="alert">{state.message}</div>}

      <button className="button" disabled={pending} type="submit">
        {pending ? "Saving customer…" : "Save customer"}
      </button>
    </form>
  );
}
