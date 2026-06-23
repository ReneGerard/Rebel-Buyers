import { notFound } from "next/navigation";
import { getCurrentUser } from "@/lib/supabase/auth";
import { createClient } from "@/lib/supabase/server";
import { ItemList } from "./item-list";

export default async function PublicWishlistPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;
  const supabase = await createClient();

  const { data: wishlist } = await supabase
    .from("wishlists")
    .select("id, owner_id, title, description")
    .eq("share_slug", slug)
    .maybeSingle();

  if (!wishlist) {
    notFound();
  }

  const { data: items, error: itemsError } = await supabase
    .from("items")
    .select("id, title, merchant_url, price, image_url, note, created_at")
    .eq("wishlist_id", wishlist.id)
    .order("created_at", { ascending: false });

  if (itemsError) {
    throw new Error(itemsError.message);
  }

  const user = await getCurrentUser();
  const isOwner = user?.id === wishlist.owner_id;

  // The owner must never see purchase status for their own list — skip the query
  // entirely rather than fetching and hiding it, so there's nothing to leak.
  let purchasedItemIds: string[] = [];
  if (!isOwner && items.length > 0) {
    const { data: purchases, error: purchasesError } = await supabase
      .from("purchases")
      .select("item_id")
      .in(
        "item_id",
        items.map((item) => item.id)
      );

    if (purchasesError) {
      throw new Error(purchasesError.message);
    }

    purchasedItemIds = purchases.map((purchase) => purchase.item_id);
  }

  return (
    <main className="mx-auto max-w-2xl px-4 py-10">
      <h1 className="text-2xl font-semibold">{wishlist.title}</h1>
      {wishlist.description && (
        <p className="mt-2 text-sm text-gray-600">{wishlist.description}</p>
      )}

      <section className="mt-8">
        <h2 className="mb-3 text-lg font-medium">Items</h2>
        {items.length === 0 ? (
          <p className="text-sm text-gray-500">Aucun item pour le moment.</p>
        ) : (
          <ItemList
            wishlistId={wishlist.id}
            items={items}
            initialPurchasedItemIds={purchasedItemIds}
            isOwner={isOwner}
          />
        )}
      </section>
    </main>
  );
}
