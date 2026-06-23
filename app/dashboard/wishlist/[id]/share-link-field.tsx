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
    <div className="flex items-center gap-2">
      <input
        readOnly
        value={url}
        onFocus={(event) => event.target.select()}
        className="flex-1 rounded-md border border-gray-300 px-3 py-2 text-sm text-gray-600"
      />
      <button
        type="button"
        onClick={handleCopy}
        className="rounded-md bg-gray-900 px-3 py-2 text-sm font-medium text-white"
      >
        {copied ? "Copié !" : "Copier le lien"}
      </button>
    </div>
  );
}
