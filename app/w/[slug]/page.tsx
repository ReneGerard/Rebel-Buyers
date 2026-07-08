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

  // The owner must never see purchase status — skip the query entirely.
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
    <>
      {/* Hero header */}
      <div className="bg-gradient-to-br from-brand-50 to-warm-100 border-b border-warm-200">
        <div className="mx-auto max-w-2xl px-4 py-10">
          {isOwner && (
            <div className="mb-4 inline-flex items-center gap-2 rounded-full bg-warm-200 px-3 py-1 text-xs font-medium text-warm-600">
              <span>👁</span>
              <span>Tu es le créateur de cette liste — les achats sont cachés pour toi.</span>
            </div>
          )}
          <h1 className="font-display text-3xl font-bold text-warm-900 sm:text-4xl">
            {wishlist.title}
          </h1>
          {wishlist.description && (
            <p className="mt-3 text-warm-600">{wishlist.description}</p>
          )}
          {!isOwner && (
            <p className="mt-4 text-sm text-warm-500">
              Clique sur <strong className="text-warm-700">🎁 Je l&apos;offre !</strong> pour réserver un cadeau — les autres voient qu&apos;il est pris, mais pas par qui.
            </p>
          )}
        </div>
      </div>

      <main className="mx-auto max-w-2xl px-4 py-8">
        {items.length === 0 ? (
          <div className="card flex flex-col items-center py-16 text-center">
            <span className="text-5xl">🎁</span>
            <p className="mt-5 font-display text-lg font-semibold text-warm-900">
              La liste est encore vide
            </p>
            <p className="mt-2 text-sm text-warm-500">
              Les items apparaîtront ici dès qu&apos;ils seront ajoutés.
            </p>
          </div>
        ) : (
          <ItemList
            wishlistId={wishlist.id}
            items={items}
            initialPurchasedItemIds={purchasedItemIds}
            isOwner={isOwner}
          />
        )}
      </main>
    </>
  );
}
