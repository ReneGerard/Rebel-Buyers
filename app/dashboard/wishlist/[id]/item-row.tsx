"use client";

import { useActionState, useState } from "react";
import type { Database } from "@/lib/supabase/database.types";
import { deleteItem, updateItem, type ItemActionState } from "./actions";

type Item = Pick<
  Database["public"]["Tables"]["items"]["Row"],
  "id" | "title" | "merchant_url" | "price" | "image_url" | "note"
>;

const initialState: ItemActionState = { error: null, success: false };

export function ItemRow({ item, wishlistId }: { item: Item; wishlistId: string }) {
  const [mode, setMode] = useState<"view" | "edit">("view");

  const updateAction = updateItem.bind(null, wishlistId, item.id);
  const [updateState, updateFormAction, isUpdatePending] = useActionState(
    updateAction,
    initialState
  );

  const deleteAction = deleteItem.bind(null, wishlistId, item.id);
  const [deleteState, deleteFormAction, isDeletePending] = useActionState(
    deleteAction,
    initialState
  );

  // Reset to view mode after a successful update — done during render per React's
  // "adjusting state when a value changes" pattern.
  const [handledUpdateState, setHandledUpdateState] = useState(updateState);
  if (updateState !== handledUpdateState) {
    setHandledUpdateState(updateState);
    if (updateState.success) {
      setMode("view");
    }
  }

  if (mode === "edit") {
    return (
      <li className="card p-5">
        <form action={updateFormAction} className="space-y-3">
          <div>
            <label className="label">Titre *</label>
            <input
              name="title"
              required
              maxLength={120}
              defaultValue={item.title}
              className="input"
            />
          </div>

          <div>
            <label className="label">Lien marchand</label>
            <input
              name="merchantUrl"
              type="url"
              defaultValue={item.merchant_url ?? ""}
              className="input"
            />
          </div>

          <div className="flex gap-3">
            <div className="flex-1">
              <label className="label">Prix (€)</label>
              <input
                name="price"
                type="number"
                min="0"
                step="0.01"
                defaultValue={item.price ?? ""}
                className="input"
              />
            </div>
            <div className="flex-1">
              <label className="label">Image (URL)</label>
              <input
                name="imageUrl"
                type="url"
                defaultValue={item.image_url ?? ""}
                className="input"
              />
            </div>
          </div>

          <div>
            <label className="label">Note</label>
            <textarea
              name="note"
              rows={2}
              maxLength={500}
              defaultValue={item.note ?? ""}
              className="input resize-none"
            />
          </div>

          {updateState.error && (
            <p className="rounded-lg bg-red-50 px-4 py-2.5 text-sm text-red-700">
              {updateState.error}
            </p>
          )}

          <div className="flex gap-2">
            <button type="submit" disabled={isUpdatePending} className="btn-primary">
              {isUpdatePending ? "Enregistrement…" : "Enregistrer"}
            </button>
            <button type="button" onClick={() => setMode("view")} className="btn-secondary">
              Annuler
            </button>
          </div>
        </form>
      </li>
    );
  }

  return (
    <li className="card flex gap-4 p-4">
      {item.image_url && (
        // eslint-disable-next-line @next/next/no-img-element -- external merchant URLs
        <img
          src={item.image_url}
          alt={item.title}
          className="h-20 w-20 flex-shrink-0 rounded-xl object-cover"
        />
      )}
      <div className="flex-1 min-w-0">
        <h3 className="font-semibold text-warm-900">{item.title}</h3>
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
            Voir le lien
          </a>
        )}
        {item.note && <p className="mt-1 text-sm text-warm-500">{item.note}</p>}

        {deleteState.error && (
          <p className="mt-1 text-sm text-red-600">{deleteState.error}</p>
        )}

        <div className="mt-3 flex items-center gap-3">
          <button
            type="button"
            onClick={() => setMode("edit")}
            className="btn-secondary px-3 py-1.5 text-xs"
          >
            Éditer
          </button>
          <form
            action={deleteFormAction}
            onSubmit={(event) => {
              if (!window.confirm("Supprimer cet item ? Cette action est irréversible.")) {
                event.preventDefault();
              }
            }}
          >
            <button
              type="submit"
              disabled={isDeletePending}
              className="text-xs text-warm-400 underline hover:text-red-600 disabled:opacity-50"
            >
              {isDeletePending ? "…" : "Supprimer"}
            </button>
          </form>
        </div>
      </div>
    </li>
  );
}
