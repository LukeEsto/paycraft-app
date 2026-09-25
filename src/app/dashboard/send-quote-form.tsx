"use client";

import { useActionState } from "react";
import { sendQuote, type SendQuoteState } from "./send-quote-action";

const initialState: SendQuoteState = {};

export function SendQuoteForm({ quoteId }: { quoteId: string }) {
  const [state, action, pending] = useActionState(sendQuote, initialState);

  return (
    <form action={action} className="send-quote-form">
      <input name="quoteId" type="hidden" value={quoteId} />
      <button className="button" type="submit" disabled={pending}>{pending ? "Preparing…" : "Send quote"}</button>
      {state.message && <p className={state.previewLink ? "delivery-message" : "field-error"} role="status">{state.message}</p>}
      {state.previewLink && <a className="preview-link" href={state.previewLink}>Open mock customer link</a>}
    </form>
  );
}
