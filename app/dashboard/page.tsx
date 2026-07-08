import Link from "next/link";
import { redirect } from "next/navigation";
import { getCurrentUser } from "@/lib/supabase/auth";
import { createClient } from "@/lib/supabase/server";

export default async function DashboardPage() {
  const user = await getCurrentUser();
  if (!user) {
    redirect("/login");
  }

  const supabase = await createClient();
  const { data: wishlists, error } = await supabase
    .from("wishlists")
    .select("id, title, description, created_at, items(count)")
    .eq("owner_id", user.id)
    .order("created_at", { ascending: false });

  if (error) {
    throw new Error(error.message);
  }

  return (
    <main className="mx-auto max-w-5xl px-4 py-10">
      <div className="mb-8 flex items-center justify-between">
        <h1 className="font-display text-3xl font-bold text-warm-900">Mes wishlists</h1>
        <Link href="/dashboard/wishlist/new" className="btn-primary">
          + Nouvelle wishlist
        </Link>
      </div>

      {wishlists.length === 0 ? (
        <div className="card flex flex-col items-center py-20 text-center">
          <span className="text-5xl">🎁</span>
          <h2 className="font-display mt-5 text-xl font-semibold text-warm-900">
            Ta première wishlist t&apos;attend
          </h2>
          <p className="mt-2 max-w-sm text-sm text-warm-500">
            Crée une liste, ajoute tes envies, et partage le lien à tes proches.
          </p>
          <Link href="/dashboard/wishlist/new" className="btn-primary mt-6">
            Créer ma première wishlist
          </Link>
        </div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {wishlists.map((wishlist) => {
            const itemCount = wishlist.items[0]?.count ?? 0;
            return (
              <Link
                key={wishlist.id}
                href={`/dashboard/wishlist/${wishlist.id}`}
                className="card block p-5 transition-shadow hover:shadow-md"
              >
                <h2 className="font-display font-semibold text-warm-900">{wishlist.title}</h2>
                {wishlist.description && (
                  <p className="mt-1 line-clamp-2 text-sm text-warm-500">
                    {wishlist.description}
                  </p>
                )}
                <div className="mt-4 flex items-center justify-between">
                  <span className="text-sm text-warm-400">
                    {itemCount} item{itemCount !== 1 ? "s" : ""}
                  </span>
                  <span className="text-xs text-warm-300">
                    {new Date(wishlist.created_at).toLocaleDateString("fr-FR")}
                  </span>
                </div>
              </Link>
            );
          })}
        </div>
      )}
    </main>
  );
}
