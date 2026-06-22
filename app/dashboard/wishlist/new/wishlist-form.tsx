"use client";

import { useActionState } from "react";
import { createWishlist, type CreateWishlistState } from "./actions";

const initialState: CreateWishlistState = { error: null };

export function WishlistForm() {
  const [state, formAction, isPending] = useActionState(createWishlist, initialState);

  return (
    <form action={formAction} className="space-y-4">
      <div>
        <label htmlFor="title" className="mb-1 block text-sm font-medium text-gray-700">
          Titre
        </label>
        <input
          id="title"
          name="title"
          required
          maxLength={120}
          className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-gray-500 focus:outline-none"
        />
      </div>

      <div>
        <label htmlFor="description" className="mb-1 block text-sm font-medium text-gray-700">
          Description
        </label>
        <textarea
          id="description"
          name="description"
          rows={3}
          maxLength={500}
          className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-gray-500 focus:outline-none"
        />
      </div>

      {state.error && <p className="text-sm text-red-600">{state.error}</p>}

      <button
        type="submit"
        disabled={isPending}
        className="w-full rounded-md bg-gray-900 px-3 py-2 text-sm font-medium text-white disabled:opacity-50"
      >
        {isPending ? "..." : "Créer"}
      </button>
    </form>
  );
}
