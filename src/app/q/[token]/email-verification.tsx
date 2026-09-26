"use client";

import { useActionState } from "react";
import {
  acceptQuote,
  type AcceptQuoteState,
  startEmailVerification,
  type StartVerificationState,
  verifyEmailCode,
  type VerifyEmailState,
} from "./actions";

const initialStartState: StartVerificationState = {};
const initialVerifyState: VerifyEmailState = {};
const initialAcceptState: AcceptQuoteState = {};

interface EmailVerificationProps {
  token: string;
  alreadyVerified: boolean;
  quoteId: string;
  versionId: string;
  versionNumber: number;
  totalPence: number;
}

function formatGbp(pence: number): string {
  return new Intl.NumberFormat("en-GB", { style: "currency", currency: "GBP" }).format(pence / 100);
}

function QuoteAcceptance({
  token,
  quoteId,
  versionId,
  versionNumber,
  totalPence,
}: Omit<EmailVerificationProps, "alreadyVerified">) {
  const [state, action, pending] = useActionState(acceptQuote, initialAcceptState);

  if (state.accepted) {
    return (
      <section className="acceptance-confirmation" aria-labelledby="acceptance-confirmation-title" role="status">
        <span className="status-badge">Accepted</span>
        <h2 id="acceptance-confirmation-title">Your quote is accepted</h2>
        <p>{state.message}</p>
        <dl>
          <div><dt>Accepted version</dt><dd>{state.acceptedVersionNumber}</dd></div>
          <div><dt>Accepted amount</dt><dd>{formatGbp(state.acceptedAmountPence ?? totalPence)}</dd></div>
          {state.acceptedAt && <div><dt>Accepted at</dt><dd>{new Date(state.acceptedAt).toLocaleString("en-GB")}</dd></div>}
        </dl>
      </section>
    );
  }

  return (
    <section className="acceptance-panel" aria-labelledby="acceptance-title">
      <h2 id="acceptance-title">Accept this quote</h2>
      <p>You are accepting version {versionNumber} for a total of <strong>{formatGbp(totalPence)}</strong>.</p>
      <form action={action}>
        <input name="token" type="hidden" value={token} />
        <input name="quoteId" type="hidden" value={quoteId} />
        <input name="versionId" type="hidden" value={versionId} />
        <input name="versionNumber" type="hidden" value={versionNumber} />
        <input name="totalPence" type="hidden" value={totalPence} />
        <button className="button" type="submit" disabled={pending}>
          {pending ? "Accepting…" : `Accept quote for ${formatGbp(totalPence)}`}
        </button>
        {state.message && <p className="field-error" role="alert">{state.message}</p>}
      </form>
    </section>
  );
}

export function EmailVerification({
  token,
  alreadyVerified,
  quoteId,
  versionId,
  versionNumber,
  totalPence,
}: EmailVerificationProps) {
  const [startState, startAction, startPending] = useActionState(startEmailVerification, initialStartState);
  const [verifyState, verifyAction, verifyPending] = useActionState(verifyEmailCode, initialVerifyState);
  const hasVerification = alreadyVerified || verifyState.verified === true;

  if (hasVerification) {
    return (
      <>
        <div className="verification-success" role="status">
          {verifyState.message ?? "Email verification is complete. Acceptance still requires the original verified browser capability."}
        </div>
        <QuoteAcceptance
          token={token}
          quoteId={quoteId}
          versionId={versionId}
          versionNumber={versionNumber}
          totalPence={totalPence}
        />
      </>
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
