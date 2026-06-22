# Rebel Buyers — Claude Code Project Instructions

## Vision (résumé)
Application web de wishlist neutre (multi-marchands), permettant l'achat coordonné
de cadeaux sans dévoiler au créateur quel item a été acheté/par qui.
Phase actuelle : **MVP / Proof of Concept**.

## Scope du MVP — NE PAS dépasser sans validation explicite
✅ Dans le scope :
- Auth (email/password via Supabase Auth)
- CRUD wishlist (titre, description)
- CRUD item (titre, lien marchand, prix optionnel, image URL, note)
- Partage de liste via lien public (lecture seule pour invités non-auth)
- Marquer un item "acheté" (visible aux autres invités, PAS au créateur de la liste)
- Sync temps réel via Supabase Realtime

❌ Hors scope (Phase 2+, ne pas construire sans demande explicite) :
- Comparateur de prix / scraping marchands
- Scan UPC / caméra
- Publicité marchands, affiliation
- App mobile native (React Native) — PWA seulement pour l'instant

## Stack technique
- Next.js 14+ (App Router), TypeScript strict
- Tailwind CSS pour le styling
- Supabase : Postgres + Auth + Realtime + Storage
- Déploiement : Vercel (preview deploys sur chaque PR)
- Pas de state management externe (Zustand/Redux) tant que pas justifié

## Conventions de code
- Tout le code, noms de variables, commentaires : **en anglais**
- Communication conversationnelle avec l'utilisateur : français OK
- Composants : functional components + hooks uniquement
- Server Components par défaut, Client Components ("use client") seulement si interactivité requise
- Validation des inputs côté serveur ET client (zod recommandé)
- Pas de `any` en TypeScript — typer explicitement ou utiliser `unknown`
- Erreurs : toujours gérées explicitement, jamais de silent fail

## Base de données — conventions
- Tables en snake_case, RLS (Row Level Security) activé sur TOUTES les tables dès le départ
- Migrations Supabase versionnées dans `supabase/migrations/`
- Jamais de logique métier critique seulement côté client — dupliquer la validation en RLS policies

## Workflow Git
- Branches : `feature/nom-court`, `fix/nom-court`
- Commits descriptifs, en français ou anglais, peu importe — mais clairs
- Ne jamais commit `.env.local` ou clés API

## Quand tu n'es pas sûr du scope
Si une demande semble élargir le MVP (ex: "ajoute le scan UPC"), le signaler
explicitement avant de coder : "Ceci est hors du scope MVP défini — veux-tu
que je le développe quand même ou qu'on le mette au backlog Phase 2 ?"
