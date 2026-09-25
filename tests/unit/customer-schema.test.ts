import { describe, expect, it } from "vitest";
import { customerSchema } from "@/lib/customers/customer-schema";

describe("customer validation", () => {
  it("accepts valid customer details", () => {
    expect(customerSchema.safeParse({ fullName: "Alex Smith", email: "alex@example.com", phone: "07123456789" }).success).toBe(true);
  });

  it("normalises names, email addresses and empty phone numbers", () => {
    const result = customerSchema.parse({ fullName: " Alex Smith ", email: " Alex@Example.COM ", phone: " " });
    expect(result).toEqual({ fullName: "Alex Smith", email: "alex@example.com", phone: "" });
  });

  it("rejects an invalid email address", () => {
    expect(customerSchema.safeParse({ fullName: "Alex Smith", email: "invalid", phone: "" }).success).toBe(false);
  });

  it("rejects a short phone number when supplied", () => {
    expect(customerSchema.safeParse({ fullName: "Alex Smith", email: "alex@example.com", phone: "123" }).success).toBe(false);
  });
});
