"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import type { Database } from "@/lib/supabase/database.types";
import { ItemRow } from "./item-row";

type Item = Pick<
  Database["public"]["Tables"]["items"]["Row"],
  "id" | "title" | "merchant_url" | "price" | "image_url" | "note"
>;

export function ItemList({
  wishlistId,
  items,
  initialPurchasedItemIds,
  isOwner,
}: {
  wishlistId: string;
  items: Item[];
  initialPurchasedItemIds: string[];
  isOwner: boolean;
}) {
  const [purchasedItemIds, setPurchasedItemIds] = useState(
    () => new Set(initialPurchasedItemIds)
  );

  useEffect(() => {
    // The owner never tracks purchase status, so no need to subscribe.
    if (isOwner) return;

    const itemIds = new Set(items.map((item) => item.id));
    const supabase = createClient();
    const channel = supabase
      .channel(`purchases-${wishlistId}`)
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "purchases" },
        (payload) => {
          const purchasedItemId = (payload.new as { item_id: string }).item_id;
          if (!itemIds.has(purchasedItemId)) return;
          setPurchasedItemIds((current) => {
            if (current.has(purchasedItemId)) return current;
            return new Set(current).add(purchasedItemId);
          });
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [isOwner, wishlistId, items]);

  return (
    <ul className="space-y-3">
      {items.map((item) => (
        <ItemRow
          key={item.id}
          item={item}
          isOwner={isOwner}
          isPurchased={purchasedItemIds.has(item.id)}
          onPurchased={(itemId) =>
            setPurchasedItemIds((current) => new Set(current).add(itemId))
          }
        />
      ))}
    </ul>
  );
}
