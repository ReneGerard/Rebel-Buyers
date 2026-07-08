"use client";

import { useState } from "react";

export function ShareLinkField({ url }: { url: string }) {
  const [copied, setCopied] = useState(false);

  async function handleCopy() {
    await navigator.clipboard.writeText(url);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }

  return (
    <div className="rounded-2xl border border-brand-100 bg-brand-50 p-4">
      <p className="mb-2 text-xs font-medium uppercase tracking-wider text-brand-600">
        Lien de partage
      </p>
      <div className="flex items-center gap-2">
        <input
          readOnly
          value={url}
          onFocus={(event) => event.target.select()}
          className="flex-1 rounded-xl border border-warm-200 bg-white px-3 py-2 text-sm text-warm-600 focus:outline-none"
        />
        <button
          type="button"
          onClick={handleCopy}
          className={`btn-primary transition-all ${copied ? "bg-green-600 hover:bg-green-700" : ""}`}
        >
          {copied ? "Copié !" : "Copier"}
        </button>
      </div>
    </div>
  );
}
