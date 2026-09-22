import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "PayCraft Feasibility Build",
  description: "PayCraft Phase 1 feasibility vertical slice",
  robots: { index: false, follow: false },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en-GB"><body>{children}</body></html>;
}
