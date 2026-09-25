"use client";

import { useActionState, useState } from "react";
import { createQuote, type QuoteState } from "./actions";

interface CustomerOption { id: string; fullName: string }
interface LineItem { id: number }

const initialState: QuoteState = {};

function ErrorText({ errors }: { errors?: string[] }) {
  if (!errors?.length) return null;
  return <p className="field-error">{errors[0]}</p>;
}

export function QuoteForm({ customers, selectedCustomerId }: { customers: CustomerOption[]; selectedCustomerId?: string }) {
  const [state, action, pending] = useActionState(createQuote, initialState);
  const [items, setItems] = useState<LineItem[]>([{ id: 1 }]);
  const [nextId, setNextId] = useState(2);

  function addItem() {
    if (items.length >= 25) return;
    setItems((current) => [...current, { id: nextId }]);
    setNextId((current) => current + 1);
  }

  function removeItem(id: number) {
    setItems((current) => current.filter((item) => item.id !== id));
  }

  return (
    <form action={action} className="form-stack" noValidate>
      <div className="field">
        <label htmlFor="customerId">Customer</label>
        <select id="customerId" name="customerId" defaultValue={selectedCustomerId ?? ""} required>
          <option value="" disabled>Select customer</option>
          {customers.map((customer) => <option key={customer.id} value={customer.id}>{customer.fullName}</option>)}
        </select>
        <ErrorText errors={state.errors?.customerId} />
      </div>

      <div className="field">
        <label htmlFor="jobTitle">Job title</label>
        <input id="jobTitle" name="jobTitle" required />
        <ErrorText errors={state.errors?.jobTitle} />
      </div>

      <div className="field">
        <label htmlFor="scope">Scope of work</label>
        <textarea id="scope" name="scope" rows={6} required />
        <ErrorText errors={state.errors?.scope} />
      </div>

      <fieldset className="line-items">
        <legend>Quote items</legend>
        {items.map((item, index) => (
          <div className="line-item" key={item.id}>
            <div className="line-item-heading">
              <strong>Item {index + 1}</strong>
              {items.length > 1 && <button className="text-button" type="button" onClick={() => removeItem(item.id)}>Remove</button>}
            </div>
            <div className="field">
              <label htmlFor={`item-description-${item.id}`}>Description</label>
              <input id={`item-description-${item.id}`} name="itemDescription" required />
            </div>
            <div className="form-grid">
              <div className="field">
                <label htmlFor={`item-quantity-${item.id}`}>Quantity</label>
                <input id={`item-quantity-${item.id}`} name="itemQuantity" inputMode="decimal" defaultValue="1" required />
              </div>
              <div className="field">
                <label htmlFor={`item-amount-${item.id}`}>Unit price (£)</label>
                <input id={`item-amount-${item.id}`} name="itemUnitAmount" inputMode="decimal" placeholder="0.00" required />
              </div>
            </div>
          </div>
        ))}
        <ErrorText errors={state.errors?.items} />
        <button className="button secondary-button" type="button" onClick={addItem} disabled={items.length >= 25}>Add item</button>
      </fieldset>

      {state.message && <div className="form-message" role="alert">{state.message}</div>}
      <button className="button" disabled={pending} type="submit">{pending ? "Creating quote…" : "Create draft quote"}</button>
    </form>
  );
}
