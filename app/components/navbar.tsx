import Image from "next/image";
import Link from "next/link";
import logo from "../../public/logo.png";
import { getCurrentUser } from "@/lib/supabase/auth";
import { signOut } from "../auth-actions";

export async function Navbar() {
  const user = await getCurrentUser();

  return (
    <nav className="sticky top-0 z-50 border-b border-warm-200 bg-warm-50/80 backdrop-blur-sm">
      <div className="mx-auto flex max-w-5xl items-center justify-between px-4 py-3">
        <Link href="/" className="flex items-center transition-opacity hover:opacity-80">
          <Image src={logo} alt="Rebel Buyers" height={36} className="h-9 w-auto" />
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
