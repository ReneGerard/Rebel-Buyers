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
    <main className="mx-auto max-w-3xl px-4 py-10">
      <div className="mb-6 flex items-center justify-between">
        <h1 className="text-2xl font-semibold">Mes wishlists</h1>
        <Link
          href="/dashboard/wishlist/new"
          className="rounded-md bg-gray-900 px-4 py-2 text-sm font-medium text-white"
        >
          Créer une wishlist
        </Link>
      </div>

      {wishlists.length === 0 ? (
        <p className="text-sm text-gray-500">Aucune wishlist pour le moment.</p>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2">
          {wishlists.map((wishlist) => {
            const itemCount = wishlist.items[0]?.count ?? 0;
            return (
              <Link
                key={wishlist.id}
                href={`/dashboard/wishlist/${wishlist.id}`}
                className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm transition hover:border-gray-300 hover:shadow"
              >
                <h2 className="font-medium text-gray-900">{wishlist.title}</h2>
                <p className="mt-1 text-sm text-gray-500">
                  {itemCount} item{itemCount === 1 ? "" : "s"}
                </p>
                <p className="mt-2 text-xs text-gray-400">
                  Créée le {new Date(wishlist.created_at).toLocaleDateString("fr-FR")}
                </p>
              </Link>
            );
          })}
        </div>
      )}
    </main>
  );
}
