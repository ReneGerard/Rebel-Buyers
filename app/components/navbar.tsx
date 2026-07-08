import Link from "next/link";
import { getCurrentUser } from "@/lib/supabase/auth";
import { signOut } from "../auth-actions";

export async function Navbar() {
  const user = await getCurrentUser();

  return (
    <nav className="sticky top-0 z-50 border-b border-warm-200 bg-warm-50/80 backdrop-blur-sm">
      <div className="mx-auto flex max-w-5xl items-center justify-between px-4 py-3">
        <Link
          href="/"
          className="font-display text-xl font-bold tracking-tight text-warm-900 transition-colors hover:text-brand-500"
        >
          Rebel Buyers
        </Link>
        <div className="flex items-center gap-4">
          {user ? (
            <>
              <Link href="/dashboard" className="btn-ghost font-medium">
                Mes listes
              </Link>
              <form action={signOut}>
                <button type="submit" className="btn-ghost">
                  Déconnexion
                </button>
              </form>
            </>
          ) : (
            <Link href="/login" className="btn-primary">
              Se connecter
            </Link>
          )}
        </div>
      </div>
    </nav>
  );
}
