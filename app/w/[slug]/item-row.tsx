"use client";

import { useActionState, useState } from "react";
import type { Database } from "@/lib/supabase/database.types";
import { markAsPurchased, type PurchaseActionState } from "./actions";

type Item = Pick<
  Database["public"]["Tables"]["items"]["Row"],
  "id" | "title" | "merchant_url" | "price" | "image_url" | "note"
>;

const initialState: PurchaseActionState = { error: null, success: false };

export function ItemRow({
  item,
  isOwner,
  isPurchased,
  onPurchased,
}: {
  item: Item;
  isOwner: boolean;
  isPurchased: boolean;
  onPurchased: (itemId: string) => void;
}) {
  const [formOpen, setFormOpen] = useState(false);

  const action = markAsPurchased.bind(null, item.id);
  const [state, formAction, isPending] = useActionState(action, initialState);

  // Reset the inline form and notify the parent once a submission succeeds — done
  // during render (not an effect) per React's "adjusting state when a value changes" pattern.
  const [handledState, setHandledState] = useState(state);
  if (state !== handledState) {
    setHandledState(state);
    if (state.success) {
      setFormOpen(false);
      onPurchased(item.id);
    }
  }

  return (
    <li className="flex gap-4 rounded-lg border border-gray-200 bg-white p-4">
      {item.image_url && (
        // eslint-disable-next-line @next/next/no-img-element -- external merchant URLs, can't whitelist every domain for next/image
        <img
          src={item.image_url}
          alt={item.title}
          className="h-16 w-16 rounded-md object-cover"
        />
      )}
      <div className="flex-1">
        <h3 className="font-medium text-gray-900">{item.title}</h3>
        {item.price !== null && <p className="text-sm text-gray-600">{item.price} €</p>}
        {item.merchant_url && (
          <a
            href={item.merchant_url}
            target="_blank"
            rel="noreferrer noopener"
            className="text-sm text-gray-500 underline"
          >
            Voir le lien
          </a>
        )}
        {item.note && <p className="mt-1 text-sm text-gray-500">{item.note}</p>}

        {!isOwner && (
          <div className="mt-2">
            {isPurchased ? (
              <span className="inline-block rounded-full bg-green-100 px-3 py-1 text-xs font-medium text-green-800">
                Déjà acheté
              </span>
            ) : formOpen ? (
              <form action={formAction} className="flex items-center gap-2">
                <input
                  name="purchasedByName"
                  required
                  maxLength={100}
                  placeholder="Ton prénom"
                  autoFocus
                  className="flex-1 rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-gray-500 focus:outline-none"
                />
                <button
                  type="submit"
                  disabled={isPending}
                  className="rounded-md bg-gray-900 px-3 py-2 text-sm font-medium text-white disabled:opacity-50"
                >
                  {isPending ? "..." : "Confirmer"}
                </button>
                <button
                  type="button"
                  onClick={() => setFormOpen(false)}
                  className="rounded-md bg-gray-100 px-3 py-2 text-sm font-medium text-gray-700"
                >
                  Annuler
                </button>
              </form>
            ) : (
              <button
                type="button"
                onClick={() => setFormOpen(true)}
                className="rounded-md bg-gray-900 px-3 py-2 text-sm font-medium text-white"
              >
                Marquer comme acheté
              </button>
            )}
            {state.error && <p className="mt-1 text-sm text-red-600">{state.error}</p>}
          </div>
        )}
      </div>
    </li>
  );
}
