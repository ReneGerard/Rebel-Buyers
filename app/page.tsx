import Link from "next/link";
import { getCurrentUser } from "@/lib/supabase/auth";

export default async function HomePage() {
  const user = await getCurrentUser();

  return (
    <main className="flex min-h-[calc(100dvh-3.5rem)] flex-col items-center justify-center px-4 py-16 text-center">
      <div className="mx-auto max-w-2xl">
        <p className="mb-4 text-sm font-semibold uppercase tracking-widest text-brand-500">
          Cadeaux coordonnés
        </p>
        <h1 className="font-display text-4xl font-bold leading-tight tracking-tight text-warm-900 sm:text-5xl">
          Des cadeaux qui surprennent,
          <br className="hidden sm:block" /> sans se marcher dessus.
        </h1>
        <p className="mx-auto mt-6 max-w-lg text-lg text-warm-500">
          Créez votre wishlist, partagez le lien — vos proches voient ce qui est déjà acheté, mais jamais par qui.
        </p>

        {user ? (
          <div className="mt-10 flex justify-center">
            <Link href="/dashboard" className="btn-primary px-8 py-3 text-base">
              Voir mes wishlists →
            </Link>
          </div>
        ) : (
          <div className="mt-10 flex flex-col items-center gap-3 sm:flex-row sm:justify-center">
            <Link href="/login" className="btn-primary px-8 py-3 text-base">
              Créer un compte
            </Link>
            <Link href="/login" className="btn-secondary px-8 py-3 text-base">
              Se connecter
            </Link>
          </div>
        )}

        <div className="mt-16 grid gap-6 text-left sm:grid-cols-3">
          {[
            {
              icon: "🎁",
              title: "Liste sans friction",
              body: "Ajoutez n'importe quel article de n'importe quel site en 30 secondes.",
            },
            {
              icon: "🤫",
              title: "Surprises préservées",
              body: "Le créateur de la liste ne voit jamais qui a acheté quoi.",
            },
            {
              icon: "⚡",
              title: "Temps réel",
              body: "Les statuts d'achat se mettent à jour instantanément pour tous.",
            },
          ].map(({ icon, title, body }) => (
            <div key={title} className="card p-5">
              <span className="text-2xl">{icon}</span>
              <h3 className="mt-3 font-display text-base font-semibold text-warm-900">{title}</h3>
              <p className="mt-1 text-sm text-warm-500">{body}</p>
            </div>
          ))}
        </div>
      </div>
    </main>
  );
}
