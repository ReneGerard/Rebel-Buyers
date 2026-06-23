"use client";

import { useActionState, useEffect, useRef } from "react";
import { createItem, type ItemActionState } from "./actions";

const initialState: ItemActionState = { error: null, success: false };

export function AddItemForm({ wishlistId }: { wishlistId: string }) {
  const action = createItem.bind(null, wishlistId);
  const [state, formAction, isPending] = useActionState(action, initialState);
  const formRef = useRef<HTMLFormElement>(null);

  useEffect(() => {
    if (state.success) {
      formRef.current?.reset();
    }
  }, [state]);

  return (
    <form ref={formRef} action={formAction} className="space-y-3">
      <div>
        <label htmlFor="title" className="mb-1 block text-sm font-medium text-gray-700">
          Titre *
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
        <label htmlFor="merchantUrl" className="mb-1 block text-sm font-medium text-gray-700">
          Lien
        </label>
        <input
          id="merchantUrl"
          name="merchantUrl"
          type="url"
          placeholder="https://..."
          className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-gray-500 focus:outline-none"
        />
      </div>

      <div className="flex gap-3">
        <div className="flex-1">
          <label htmlFor="price" className="mb-1 block text-sm font-medium text-gray-700">
            Prix
          </label>
          <input
            id="price"
            name="price"
            type="number"
            min="0"
            step="0.01"
            className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-gray-500 focus:outline-none"
          />
        </div>
        <div className="flex-1">
          <label htmlFor="imageUrl" className="mb-1 block text-sm font-medium text-gray-700">
            Image (URL)
          </label>
          <input
            id="imageUrl"
            name="imageUrl"
            type="url"
            placeholder="https://..."
            className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-gray-500 focus:outline-none"
          />
        </div>
      </div>

      <div>
        <label htmlFor="note" className="mb-1 block text-sm font-medium text-gray-700">
          Notes
        </label>
        <textarea
          id="note"
          name="note"
          rows={2}
          maxLength={500}
          className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-gray-500 focus:outline-none"
        />
      </div>

      {state.error && <p className="text-sm text-red-600">{state.error}</p>}

      <button
        type="submit"
        disabled={isPending}
        className="rounded-md bg-gray-900 px-4 py-2 text-sm font-medium text-white disabled:opacity-50"
      >
        {isPending ? "..." : "Ajouter l'item"}
      </button>
    </form>
  );
}
