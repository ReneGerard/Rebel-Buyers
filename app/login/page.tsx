"use client";

import { useRouter } from "next/navigation";
import { useState, type FormEvent } from "react";
import { z } from "zod";
import { createClient } from "@/lib/supabase/client";

const credentialsSchema = z.object({
  email: z.string().email("Adresse email invalide"),
  password: z.string().min(6, "6 caractères minimum"),
});

type Mode = "login" | "signup";

export default function LoginPage() {
  const router = useRouter();
  const [mode, setMode] = useState<Mode>("login");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setInfo(null);

    const parsed = credentialsSchema.safeParse({ email, password });
    if (!parsed.success) {
      setError(parsed.error.issues[0].message);
      return;
    }

    setIsSubmitting(true);
    const supabase = createClient();

    if (mode === "login") {
      const { error: signInError } = await supabase.auth.signInWithPassword(parsed.data);
      setIsSubmitting(false);
      if (signInError) {
        setError(signInError.message);
        return;
      }
      router.push("/dashboard");
      router.refresh();
      return;
    }

    const { data, error: signUpError } = await supabase.auth.signUp(parsed.data);
    setIsSubmitting(false);
    if (signUpError) {
      setError(signUpError.message);
      return;
    }
    if (data.session) {
      router.push("/dashboard");
      router.refresh();
      return;
    }
    setInfo("Compte créé. Vérifie ta boîte mail pour confirmer ton adresse.");
  }

  return (
    <main className="flex min-h-[calc(100dvh-3.5rem)] items-center justify-center px-4 py-12">
      <div className="card w-full max-w-sm p-8">
        <h1 className="font-display mb-6 text-center text-2xl font-bold text-warm-900">
          {mode === "login" ? "Bon retour !" : "Créer un compte"}
        </h1>

        <div className="mb-6 flex gap-1 rounded-xl bg-warm-100 p-1">
          <button
            type="button"
            onClick={() => setMode("login")}
            className={`flex-1 rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
              mode === "login"
                ? "bg-white text-warm-900 shadow-sm"
                : "text-warm-500 hover:text-warm-700"
            }`}
          >
            Connexion
          </button>
          <button
            type="button"
            onClick={() => setMode("signup")}
            className={`flex-1 rounded-lg px-3 py-2 text-sm font-medium transition-colors ${
              mode === "signup"
                ? "bg-white text-warm-900 shadow-sm"
                : "text-warm-500 hover:text-warm-700"
            }`}
          >
            Inscription
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label htmlFor="email" className="label">
              Email
            </label>
            <input
              id="email"
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="toi@exemple.com"
              className="input"
            />
          </div>

          <div>
            <label htmlFor="password" className="label">
              Mot de passe
            </label>
            <input
              id="password"
              type="password"
              required
              minLength={6}
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="6 caractères minimum"
              className="input"
            />
          </div>

          {error && (
            <p className="rounded-lg bg-red-50 px-4 py-2.5 text-sm text-red-700">{error}</p>
          )}
          {info && (
            <p className="rounded-lg bg-green-50 px-4 py-2.5 text-sm text-green-700">{info}</p>
          )}

          <button type="submit" disabled={isSubmitting} className="btn-primary w-full py-3">
            {isSubmitting
              ? "Chargement…"
              : mode === "login"
                ? "Se connecter"
                : "Créer mon compte"}
          </button>
        </form>
      </div>
    </main>
  );
}
