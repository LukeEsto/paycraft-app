"use server";

import { cookies } from "next/headers";
import { z } from "zod";
import { hashInviteToken } from "@/lib/invites/token";
import {
  createVerificationCode,
  createVerificationGrant,
  hashVerificationCode,
  hashVerificationGrant,
  maskEmail,
} from "@/lib/invites/verification";
import { getNotificationProvider } from "@/lib/notifications/provider";
import {
  parseQuoteAcceptanceResult,
  quoteAcceptanceRequestSchema,
} from "@/lib/quotes/acceptance";
import { createSupabaseServerClient } from "@/lib/supabase/server";

const tokenSchema = z.string().regex(/^[A-Za-z0-9_-]{43}$/);
const verificationSchema = z.object({
  token: tokenSchema,
  code: z.string().trim().regex(/^\d{6}$/),
});

const CODE_LIFETIME_MINUTES = 10;
const GRANT_LIFETIME_MINUTES = 30;
const VERIFICATION_COOKIE_NAME = "paycraft_quote_verification";

export interface StartVerificationState {
  message?: string;
  challengeStarted?: boolean;
  mockCode?: string;
}

export interface VerifyEmailState {
  message?: string;
  verified?: boolean;
}

export interface AcceptQuoteState {
  message?: string;
  accepted?: boolean;
  acceptedAt?: string;
  acceptedAmountPence?: number;
  acceptedVersionNumber?: number;
}

function pepper(): string {
  const value = process.env.INVITE_TOKEN_PEPPER;
  if (!value) throw new Error("INVITE_TOKEN_PEPPER is not configured.");
  return value;
}

export async function startEmailVerification(
  _previousState: StartVerificationState,
  formData: FormData,
): Promise<StartVerificationState> {
  const parsedToken = tokenSchema.safeParse(formData.get("token"));
  if (!parsedToken.success) return { message: "Verification could not be started for this quote link." };

  const notificationProvider = getNotificationProvider();
  const inviteTokenHash = hashInviteToken(parsedToken.data, pepper());
  const code = createVerificationCode();
  const expiresAt = new Date(Date.now() + CODE_LIFETIME_MINUTES * 60 * 1000);
  const supabase = await createSupabaseServerClient();
  const { data: recipientEmail, error } = await supabase.rpc("start_quote_verification", {
    candidate_token_hash: inviteTokenHash,
    verification_code_hash: hashVerificationCode(code, inviteTokenHash, pepper()),
    verification_expires_at: expiresAt.toISOString(),
  });

  if (error || typeof recipientEmail !== "string") {
    return { message: "Verification could not be started for this quote link." };
  }

  await notificationProvider.send({
    to: recipientEmail,
    subject: "Your PayCraft verification code",
    text: `Your PayCraft verification code is ${code}. It expires in ${CODE_LIFETIME_MINUTES} minutes.`,
  });

  return {
    challengeStarted: true,
    message: `A mock verification message was prepared for ${maskEmail(recipientEmail)}.`,
    mockCode: code,
  };
}

export async function verifyEmailCode(
  _previousState: VerifyEmailState,
  formData: FormData,
): Promise<VerifyEmailState> {
  const parsed = verificationSchema.safeParse({
    token: formData.get("token"),
    code: formData.get("code"),
  });
  if (!parsed.success) return { message: "The code could not be verified." };

  const inviteTokenHash = hashInviteToken(parsed.data.token, pepper());
  const grant = createVerificationGrant();
  const grantExpiresAt = new Date(Date.now() + GRANT_LIFETIME_MINUTES * 60 * 1000);
  const supabase = await createSupabaseServerClient();
  const { data: verified, error } = await supabase.rpc("verify_quote_email", {
    candidate_token_hash: inviteTokenHash,
    candidate_code_hash: hashVerificationCode(parsed.data.code, inviteTokenHash, pepper()),
    verification_grant_hash: hashVerificationGrant(grant, pepper()),
    verification_grant_expires_at: grantExpiresAt.toISOString(),
  });

  if (error || verified !== true) return { message: "The code could not be verified." };

  const cookieStore = await cookies();
  cookieStore.set(VERIFICATION_COOKIE_NAME, grant, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    expires: grantExpiresAt,
    priority: "high",
  });

  return {
    verified: true,
    message: "Email verified. Review the total below before accepting this exact quote version.",
  };
}

export async function acceptQuote(
  _previousState: AcceptQuoteState,
  formData: FormData,
): Promise<AcceptQuoteState> {
  const publicFailure = {
    message: "This quote could not be accepted. Refresh the quote or ask the tradesperson for a new link.",
  };
  const parsed = quoteAcceptanceRequestSchema.safeParse({
    token: formData.get("token"),
    quoteId: formData.get("quoteId"),
    versionId: formData.get("versionId"),
    versionNumber: formData.get("versionNumber"),
    totalPence: formData.get("totalPence"),
  });
  if (!parsed.success) return publicFailure;

  const cookieStore = await cookies();
  const grant = cookieStore.get(VERIFICATION_COOKIE_NAME)?.value;
  if (!grant || !/^[A-Za-z0-9_-]{43}$/.test(grant)) return publicFailure;

  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("accept_quote", {
    candidate_token_hash: hashInviteToken(parsed.data.token, pepper()),
    candidate_grant_hash: hashVerificationGrant(grant, pepper()),
    expected_quote_id: parsed.data.quoteId,
    expected_version_id: parsed.data.versionId,
    expected_version_number: parsed.data.versionNumber,
    expected_total_pence: parsed.data.totalPence,
  });
  const accepted = error ? null : parseQuoteAcceptanceResult(data);

  if (!accepted) return publicFailure;

  cookieStore.delete(VERIFICATION_COOKIE_NAME);
  return {
    accepted: true,
    acceptedAt: accepted.accepted_at,
    acceptedAmountPence: accepted.accepted_amount_pence,
    acceptedVersionNumber: accepted.accepted_version_number,
    message: accepted.already_accepted
      ? "This exact quote was already accepted."
      : "Quote accepted successfully.",
  };
}
