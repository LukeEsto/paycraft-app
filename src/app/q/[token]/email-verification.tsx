"use client";

import { useActionState } from "react";
import {
  startEmailVerification,
  type StartVerificationState,
  verifyEmailCode,
  type VerifyEmailState,
} from "./actions";

const initialStartState: StartVerificationState = {};
const initialVerifyState: VerifyEmailState = {};

export function EmailVerification({ token, alreadyVerified }: { token: string; alreadyVerified: boolean }) {
  const [startState, startAction, startPending] = useActionState(startEmailVerification, initialStartState);
  const [verifyState, verifyAction, verifyPending] = useActionState(verifyEmailCode, initialVerifyState);

  if (verifyState.verified) {
    return <div className="verification-success" role="status">{verifyState.message}</div>;
  }

  if (alreadyVerified) {
    return (
      <div className="verification-success" role="status">
        Email verification has already been completed for this quote. Consequential actions will also require the original verified browser capability.
      </div>
    );
  }

  return (
    <section className="verification-panel" aria-labelledby="verification-title">
      <h2 id="verification-title">Verify your email</h2>
      <p>Before PayCraft can grant acceptance authority, verify access to the email address selected by the tradesperson.</p>

      {!startState.challengeStarted ? (
        <form action={startAction}>
          <input name="token" type="hidden" value={token} />
          <button className="button" type="submit" disabled={startPending}>
            {startPending ? "Preparing code…" : "Send verification code"}
          </button>
          {startState.message && <p className="field-error" role="status">{startState.message}</p>}
        </form>
      ) : (
        <>
          <p className="delivery-message" role="status">{startState.message}</p>
          <div className="mock-code" aria-label="Development mock verification code">
            <span>Mock delivery code</span>
            <strong>{startState.mockCode}</strong>
          </div>
          <form action={verifyAction} className="verification-form" noValidate>
            <input name="token" type="hidden" value={token} />
            <div className="field">
              <label htmlFor="verification-code">Six-digit code</label>
              <input
                id="verification-code"
                name="code"
                type="text"
                inputMode="numeric"
                autoComplete="one-time-code"
                pattern="[0-9]{6}"
                maxLength={6}
                required
              />
            </div>
            <button className="button" type="submit" disabled={verifyPending}>
              {verifyPending ? "Verifying…" : "Verify email"}
            </button>
            {verifyState.message && <p className="field-error" role="status">{verifyState.message}</p>}
          </form>
        </>
      )}
    </section>
  );
}
