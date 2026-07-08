"use client";

import { useActionState, useEffect, useRef, useState, useTransition } from "react";
import { createItem, fetchLinkMetadata, type ItemActionState } from "./actions";

const initialState: ItemActionState = { error: null, success: false };

export function AddItemForm({ wishlistId }: { wishlistId: string }) {
  const action = createItem.bind(null, wishlistId);
  const [state, formAction, isPending] = useActionState(action, initialState);
  const formRef = useRef<HTMLFormElement>(null);

  const [title, setTitle] = useState("");
  const [imageUrl, setImageUrl] = useState("");
  const [price, setPrice] = useState("");
  const [isFetchingMeta, startMetaFetch] = useTransition();

  useEffect(() => {
    if (state.success) {
      formRef.current?.reset();
      setTitle("");
      setImageUrl("");
      setPrice("");
    }
  }, [state]);

  function handleUrlPaste(e: React.ClipboardEvent<HTMLInputElement>) {
    const url = e.clipboardData.getData("text").trim();
    if (!url.startsWith("http")) return;
    startMetaFetch(async () => {
      const meta = await fetchLinkMetadata(url);
      if (!meta) return;
      if (meta.title) setTitle((prev) => (prev === "" ? meta.title! : prev));
      if (meta.imageUrl) setImageUrl((prev) => (prev === "" ? meta.imageUrl! : prev));
      if (meta.price) setPrice((prev) => (prev === "" ? meta.price! : prev));
    });
  }

  return (
    <form ref={formRef} action={formAction} className="space-y-4">
      <div>
        <div className="mb-1.5 flex items-baseline justify-between">
          <label htmlFor="add-title" className="label mb-0">
            Titre *
          </label>
          {title.length >= 100 && (
            <span
              className={`text-xs tabular-nums ${title.length >= 120 ? "text-red-500" : "text-warm-400"}`}
            >
              {title.length}/120
            </span>
          )}
        </div>
        <input
          id="add-title"
          name="title"
          required
          maxLength={120}
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="Nom de l'article"
          className="input"
        />
      </div>

      <div>
        <label htmlFor="add-merchantUrl" className="label">
          Lien marchand
          {isFetchingMeta && (
            <span className="ml-2 text-xs font-normal text-warm-400">Chargement…</span>
          )}
        </label>
        <input
          id="add-merchantUrl"
          name="merchantUrl"
          type="url"
          placeholder="https://..."
          onPaste={handleUrlPaste}
          className="input"
        />
      </div>

      <div className="flex gap-3">
        <div className="flex-1">
          <label htmlFor="add-price" className="label">
            Prix (€)
          </label>
          <input
            id="add-price"
            name="price"
            type="number"
            min="0"
            step="0.01"
            value={price}
            onChange={(e) => setPrice(e.target.value)}
            placeholder="0.00"
            className="input"
          />
        </div>
        <div className="flex-1">
          <label htmlFor="add-imageUrl" className="label">
            Image (URL)
          </label>
          <input
            id="add-imageUrl"
            name="imageUrl"
            type="url"
            placeholder="https://..."
            value={imageUrl}
            onChange={(e) => setImageUrl(e.target.value)}
            className="input"
          />
        </div>
      </div>

      <div>
        <label htmlFor="add-note" className="label">
          Note <span className="font-normal text-warm-400">(facultatif)</span>
        </label>
        <textarea
          id="add-note"
          name="note"
          rows={2}
          maxLength={500}
          placeholder="Taille, couleur, préférence…"
          className="input resize-none"
        />
      </div>

      {state.error && (
        <p className="rounded-lg bg-red-50 px-4 py-2.5 text-sm text-red-700">{state.error}</p>
      )}

      <button type="submit" disabled={isPending} className="btn-primary">
        {isPending ? "Ajout…" : "Ajouter l'item"}
      </button>
    </form>
  );
}
