import { headers } from "next/headers";
import { notFound, redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/supabase/auth";
import { createClient } from "@/lib/supabase/server";
import { AddItemForm } from "./add-item-form";
import { ItemRow } from "./item-row";
import { ShareLinkField } from "./share-link-field";

export default async function WishlistDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const user = await getCurrentUser();
  if (!user) {
    redirect("/login");
  }

  const { id } = await params;
  const supabase = await createClient();

  const { data: wishlist } = await supabase
    .from("wishlists")
    .select("id, title, description, share_slug")
    .eq("id", id)
    .eq("owner_id", user.id)
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

  const headersList = await headers();
  const host = headersList.get("host");
  const protocol =
    headersList.get("x-forwarded-proto") ??
    (process.env.NODE_ENV === "production" ? "https" : "http");
  const shareUrl = `${protocol}://${host}/w/${wishlist.share_slug}`;

  return (
    <main className="mx-auto max-w-2xl px-4 py-10">
      <h1 className="text-2xl font-semibold">{wishlist.title}</h1>
      {wishlist.description && (
        <p className="mt-2 text-sm text-gray-600">{wishlist.description}</p>
      )}

      <div className="mt-4">
        <ShareLinkField url={shareUrl} />
      </div>

      <section className="mt-8">
        <h2 className="mb-3 text-lg font-medium">Items</h2>
        {items.length === 0 ? (
          <p className="text-sm text-gray-500">Aucun item pour le moment.</p>
        ) : (
          <ul className="space-y-3">
            {items.map((item) => (
              <ItemRow key={item.id} item={item} wishlistId={wishlist.id} />
            ))}
          </ul>
        )}
      </section>

      <section className="mt-8 rounded-lg border border-gray-200 bg-white p-4">
        <h2 className="mb-3 text-lg font-medium">Ajouter un item</h2>
        <AddItemForm wishlistId={wishlist.id} />
      </section>
    </main>
  );
}
