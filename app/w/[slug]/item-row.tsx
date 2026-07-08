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
  // during render per React's "adjusting state when a value changes" pattern.
  const [handledState, setHandledState] = useState(state);
  if (state !== handledState) {
    setHandledState(state);
    if (state.success) {
      setFormOpen(false);
      onPurchased(item.id);
    }
  }

  return (
    <li
      className={`card overflow-hidden transition-opacity ${isPurchased ? "opacity-60" : ""}`}
    >
      <div className="flex gap-4 p-4">
        {item.image_url && (
          // eslint-disable-next-line @next/next/no-img-element -- external merchant URLs
          <img
            src={item.image_url}
            alt={item.title}
            className="h-20 w-20 flex-shrink-0 rounded-xl object-cover sm:h-24 sm:w-24"
          />
        )}
        <div className="flex-1 min-w-0">
          <h3 className={`font-semibold ${isPurchased ? "line-through text-warm-400" : "text-warm-900"}`}>
            {item.title}
          </h3>
          {item.price !== null && (
            <p className="mt-0.5 text-sm font-medium text-brand-600">{item.price} €</p>
          )}
          {item.merchant_url && (
            <a
              href={item.merchant_url}
              target="_blank"
              rel="noreferrer noopener"
              className="mt-0.5 inline-block text-sm text-warm-400 underline hover:text-warm-600"
            >
              Voir le produit
            </a>
          )}
          {item.note && <p className="mt-1 text-sm text-warm-500">{item.note}</p>}
        </div>
      </div>

      {!isOwner && (
        <div className="border-t border-warm-100 px-4 py-3">
          {isPurchased ? (
            <div className="flex items-center gap-2 text-sm font-medium text-green-700">
              <span className="text-base">✓</span>
              <span>Déjà réservé par quelqu&apos;un</span>
            </div>
          ) : formOpen ? (
            <form action={formAction} className="flex items-center gap-2">
              <input
                name="purchasedByName"
                required
                maxLength={100}
                placeholder="Ton prénom"
                autoFocus
                className="input flex-1"
              />
              <button type="submit" disabled={isPending} className="btn-primary">
                {isPending ? "…" : "Confirmer"}
              </button>
              <button
                type="button"
                onClick={() => setFormOpen(false)}
                className="btn-secondary"
              >
                Annuler
              </button>
            </form>
          ) : (
            <button
              type="button"
              onClick={() => setFormOpen(true)}
              className="w-full rounded-xl bg-brand-500 py-3 text-center text-sm font-semibold text-white transition-colors hover:bg-brand-600 focus:outline-none focus:ring-4 focus:ring-brand-200"
            >
              🎁 Je l&apos;offre !
            </button>
          )}
          {state.error && <p className="mt-2 text-sm text-red-600">{state.error}</p>}
        </div>
      )}
    </li>
  );
}
