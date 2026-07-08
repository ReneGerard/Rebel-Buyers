import Link from "next/link";
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
      <Link href="/dashboard" className="btn-ghost mb-6 inline-flex items-center gap-1">
        ← Mes wishlists
      </Link>

      <h1 className="font-display text-3xl font-bold text-warm-900">{wishlist.title}</h1>
      {wishlist.description && (
        <p className="mt-2 text-warm-500">{wishlist.description}</p>
      )}

      <div className="mt-6">
        <ShareLinkField url={shareUrl} />
      </div>

      <section className="mt-10">
        <h2 className="font-display mb-4 text-xl font-semibold text-warm-900">Items</h2>
        {items.length === 0 ? (
          <div className="card flex flex-col items-center py-14 text-center">
            <span className="text-4xl">✨</span>
            <p className="mt-4 font-medium text-warm-700">Aucun item pour le moment</p>
            <p className="mt-1 text-sm text-warm-400">Ajoute le premier item via le formulaire ci-dessous.</p>
          </div>
        ) : (
          <ul className="space-y-4">
            {items.map((item) => (
              <ItemRow key={item.id} item={item} wishlistId={wishlist.id} />
            ))}
          </ul>
        )}
      </section>

      <section className="card mt-8 p-6">
        <h2 className="font-display mb-5 text-xl font-semibold text-warm-900">Ajouter un item</h2>
        <AddItemForm wishlistId={wishlist.id} />
      </section>
    </main>
  );
}
