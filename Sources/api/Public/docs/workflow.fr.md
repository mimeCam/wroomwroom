# Workflows

Réfléchissez à la façon dont le travail se fait réellement dans votre entreprise. Un VP définit la direction, la tech l'exécute, le marketing le fait connaître. L'architecte parle systèmes, le designer impose une marque cohérente, les développeurs frontend/mobile/backend/ml font avancer les choses, le CEO inspire.

**Les workflows encodent des processus exacts en automatisation IA.**

## Qu'est-ce qu'un workflow ?

Un workflow définit *quel travail se produit*, *qui le fait*, et *à quelle fréquence*. C'est une structure de réunion automatisée—sauf qu'au lieu de personnes dans une salle de conférence, vous avez des personas IA travaillant à travers des niveaux dans une structure en cascade.

Chaque workflow a :
1. **Un calendrier** — Standup quotidien ? Revue de code hebdomadaire ? Surveillance horaire ? Demande de fonctionnalité unique ?
2. **Des niveaux de personas** — Qui participe, dans quel ordre, construisant sur le travail des autres

## Comment fonctionnent les niveaux (c'est là la magie)

Les niveaux s'exécutent séquentiellement. Le niveau 0 passe en premier. Le niveau 1 voit la sortie du niveau 0 et construit dessus. Le niveau 2 voit le travail du niveau 1 et ainsi de suite.

Cela reflète la façon dont le travail circule réellement :

| Monde Réel | OpenLoop |
|------------|----------|
| Rassembler la recherche | Niveau 0 : Persona chercheur + VP l'idéateur |
| Prendre une décision | Niveau 1 : Persona architecte + Designer UX |
| Implémenter | Niveau 2 : Persona frontend + Persona backend |

Chaque niveau fournit une expertise. Chaque persona voit ce qui précédait et fait son travail spécifique avec.


## De l'Idée à la Livraison : Le Modèle d'Itération

Réfléchissez à la façon dont une fonctionnalité voyage réellement à travers une entreprise :

```
💡 Le PDG (rêveur) a une vision
    ↓
🔍 Le CTO/Recherche investigue la faisabilité
    ↓
📋 Le Business écrit le plan, recherche la concurrence
    ↓
📢 Le Marketing signale les contraintes : "on ne peut pas dire ça"
    ↓
🎨 Le Design crée les maquettes
    ↓
💻 Les Développeurs construisent
    ↓
✅ La QA teste
```

Chaque niveau est une **itération**—la fonctionnalité devient plus affinée en passant par différentes mains. Le niveau 0 est l'entrée brute ("construire la fonctionnalité X"). Le niveau 1 est l'analyse ("voici comment nous pourrions aborder ça de manière unique"). Niveau suivant ("fais-le", ou "livre-le" ou "corrige ça d'abord"). 

C'est waterfall—chaque étape passe au suivant.

## Le Bac à Sable : Concevez N'Importe Quel Flux

C'est là que ça devient intéressant. OpenLoop est un **bac à sable de processus**. Vous n'êtes pas coincé avec la façon dont votre entreprise fonctionne—vous pouvez modéliser comment vous *souhaitez* qu'elle fonctionne.

**Et si...**

- Vous ajoutiez un reviewer sécurité avant le développement ?
- Vous supprimiez le goulot d'étranglement de signature CTO—qu'est-ce qui casse ?
- Vous découvriez qu'il vous manque un rôle—peut-être un rédacteur technique ?
- Le design revoyait le code pour les implications UX ?

Le concepteur de workflow est votre laboratoire organisationnel. Au lieu d'innombrables réunions pour débattre de "comment ça devrait fonctionner ?", vous concevez le flux une fois, appuyez sur play, et regardez différentes parties prenantes interagir. Voyez ce qui fonctionne. Apprenez de la simulation.

C'est le but—OpenLoop vous permet d'expérimenter avec les structures organisationnelles sans conséquences réelles. Vos personas collaboreront authentiquement dans leur expertise, comme le feraient de vraies personnes.

## Comment les workflows s'articulent

- **[Personas](persona)** sont les travailleurs assignés à chaque niveau—ils sont le "qui"
- **[Instances](instance)** exécutent les workflows selon le calendrier—elles sont le "où et quand"

Les workflows sont le pont entre "comment notre équipe fonctionne vraiment" et "l'exécution automatisée qui fonctionne de la même façon."

## Niveaux et Isolation

L'information est transmise du niveau supérieur au suivant. Il peut y avoir un ou plusieurs personas sur chaque niveau. Les personas du même niveau ne coopèrent pas—ils ne voient que les informations contextuelles du niveau supérieur et la demande principale que vous (utilisateur) avez spécifiée. 
