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

  // Reset back to view mode once a submission resolves successfully — done during
  // render (not an effect) per React's "adjusting state when a value changes" pattern.
  const [handledUpdateState, setHandledUpdateState] = useState(updateState);
  if (updateState !== handledUpdateState) {
    setHandledUpdateState(updateState);
    if (updateState.success) {
      setMode("view");
    }
  }

  if (mode === "edit") {
    return (
      <li className="rounded-lg border border-gray-200 bg-white p-4">
        <form action={updateFormAction} className="space-y-3">
          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700">Titre *</label>
            <input
              name="title"
              required
              maxLength={120}
              defaultValue={item.title}
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-gray-500 focus:outline-none"
            />
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700">Lien</label>
            <input
              name="merchantUrl"
              type="url"
              defaultValue={item.merchant_url ?? ""}
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-gray-500 focus:outline-none"
            />
          </div>

          <div className="flex gap-3">
            <div className="flex-1">
              <label className="mb-1 block text-sm font-medium text-gray-700">Prix</label>
              <input
                name="price"
                type="number"
                min="0"
                step="0.01"
                defaultValue={item.price ?? ""}
                className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-gray-500 focus:outline-none"
              />
            </div>
            <div className="flex-1">
              <label className="mb-1 block text-sm font-medium text-gray-700">
                Image (URL)
              </label>
              <input
                name="imageUrl"
                type="url"
                defaultValue={item.image_url ?? ""}
                className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-gray-500 focus:outline-none"
              />
            </div>
          </div>

          <div>
            <label className="mb-1 block text-sm font-medium text-gray-700">Notes</label>
            <textarea
              name="note"
              rows={2}
              maxLength={500}
              defaultValue={item.note ?? ""}
              className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm focus:border-gray-500 focus:outline-none"
            />
          </div>

          {updateState.error && <p className="text-sm text-red-600">{updateState.error}</p>}

          <div className="flex gap-2">
            <button
              type="submit"
              disabled={isUpdatePending}
              className="rounded-md bg-gray-900 px-3 py-2 text-sm font-medium text-white disabled:opacity-50"
            >
              {isUpdatePending ? "..." : "Enregistrer"}
            </button>
            <button
              type="button"
              onClick={() => setMode("view")}
              className="rounded-md bg-gray-100 px-3 py-2 text-sm font-medium text-gray-700"
            >
              Annuler
            </button>
          </div>
        </form>
      </li>
    );
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

        {deleteState.error && <p className="mt-1 text-sm text-red-600">{deleteState.error}</p>}

        <div className="mt-2 flex gap-2">
          <button
            type="button"
            onClick={() => setMode("edit")}
            className="text-sm font-medium text-gray-700 underline"
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
              className="text-sm font-medium text-red-600 underline disabled:opacity-50"
            >
              {isDeletePending ? "..." : "Supprimer"}
            </button>
          </form>
        </div>
      </div>
    </li>
  );
}
