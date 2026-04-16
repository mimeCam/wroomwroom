# Les Niveaux dans un Workflow

Les workflows ne s'exécutent pas tout en même temps. Ils fonctionnent par **niveaux** — des étapes séquentielles où chaque niveau construit sur la sortie du précédent.

## Qu'est-ce qu'un niveau ?

Un niveau est une étape dans le pipeline de votre workflow. Le niveau 0 s'exécute en premier. Le niveau 1 s'exécute après la fin du niveau 0, en utilisant sa sortie. Le niveau 2 construit sur le niveau 1, et ainsi de suite.

Chaque niveau contient un ou plusieurs [personas](persona.md) — les travailleurs IA qui font le travail de réflexion.

```
Niveau 0  (Recherche)        →  sortie  →
Niveau 1  (Décision)         →  sortie  →
Niveau 2  (Implémentation)
```

Chaque persona ne voit **que** la sortie du niveau directement au-dessus, plus la demande originale que vous avez fournie. Ils ne voient pas l'historique complet — seulement ce qui a été transmis.

## Lecture seule vs Lecture-écriture

Voici la règle fondamentale :

- **Niveau multi-personas** (2+ personas) → tous s'exécutent en mode **lecture seule (RO)**. Ils recherchent, analysent et produisent des rapports — mais ne peuvent pas modifier les fichiers.
- **Niveau mono-persona** (1 persona) → s'exécute en mode **lecture-écriture (RW)**. Accès complet en écriture pour agir sur ce que les niveaux précédents ont produit.

**Pourquoi ?** Plusieurs personas écrivant simultanément créeraient des conflits. Le système impose donc un schéma propre :

> Plusieurs esprits analysent, puis une seule main agit.

## Exemple rapide

Imaginons un workflow à 3 niveaux :

| Niveau | Personas | Mode | Rôle |
|--------|----------|------|------|
| 0 | Chercheur + VP | RO | Les deux investiguent indépendamment, produisent des rapports |
| 1 | Architecte + Designer | RO | Les deux planifient à partir de la sortie du niveau 0 |
| 2 | Développeur | RW | Implémente à partir des plans du niveau 1 |

Le chercheur et le VP ne voient jamais le travail de l'autre — ils ne voient que la demande. L'architecte et le designer voient la sortie combinée du niveau 0. Le développeur voit les plans du niveau 1 et les exécute.

## Isolation entre personas

Les personas du même niveau ne coopèrent pas entre eux. Ils travaillent indépendamment, chacun produisant sa propre sortie. Le niveau suivant reçoit toutes les sorties du niveau précédent comme contexte combiné.

Cette isolation est intentionnelle — elle empêche la pensée de groupe et garantit que chaque persona contribue son expertise unique sans être influencé par ses pairs.

## Voir aussi

- [Workflows](workflow.md) — le panorama complet du fonctionnement des workflows
- [Personas](persona.md) — comprendre les travailleurs assignés à chaque niveau
