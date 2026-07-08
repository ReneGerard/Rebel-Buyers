import type { Metadata } from "next";
import type { ReactNode } from "react";
import { Inter, Fraunces } from "next/font/google";
import "./globals.css";
import { Navbar } from "./components/navbar";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
});

const fraunces = Fraunces({
  subsets: ["latin"],
  variable: "--font-fraunces",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Rebel Buyers",
  description: "Wishlist neutre pour cadeaux coordonnés",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="fr" className={`${inter.variable} ${fraunces.variable}`}>
      <body className="font-sans">
        <Navbar />
        {children}
      </body>
    </html>
  );
}
