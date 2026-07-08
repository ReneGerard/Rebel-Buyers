"use client";

import { useActionState } from "react";
import { createWishlist, type CreateWishlistState } from "./actions";

const initialState: CreateWishlistState = { error: null };

export function WishlistForm() {
  const [state, formAction, isPending] = useActionState(createWishlist, initialState);

  return (
    <form action={formAction} className="space-y-4">
      <div>
        <label htmlFor="title" className="label">
          Titre
        </label>
        <input
          id="title"
          name="title"
          required
          maxLength={120}
          placeholder="Noël 2026, Anniversaire…"
          className="input"
        />
      </div>

      <div>
        <label htmlFor="description" className="label">
          Description <span className="font-normal text-warm-400">(facultatif)</span>
        </label>
        <textarea
          id="description"
          name="description"
          rows={3}
          maxLength={500}
          placeholder="Quelques mots pour tes proches…"
          className="input resize-none"
        />
      </div>

      {state.error && (
        <p className="rounded-lg bg-red-50 px-4 py-2.5 text-sm text-red-700">{state.error}</p>
      )}

      <button type="submit" disabled={isPending} className="btn-primary w-full py-3">
        {isPending ? "Création…" : "Créer la wishlist"}
      </button>
    </form>
  );
}
