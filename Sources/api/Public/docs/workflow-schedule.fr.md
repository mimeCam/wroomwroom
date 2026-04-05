# Calendrier de Workflow

## Intervalle de Répétition (every_secs)

Le champ `every_secs` définit le temps minimum entre les exécutions d'un workflow.

| Valeur | Comportement |
|--------|--------------|
| **-1** | Démarrage — s'exécute une fois au démarrage ou à la reprise du service openloop, ne se répète jamais. Se déclenche automatiquement après un redémarrage du système d'exploitation, ou lors de la réinstallation/mise à jour d'openloop vers une nouvelle version. |
| **0** | Manuel — le workflow s'exécute une fois quand déclenché, ne se répète jamais |
| **1** | Continu — planifie la prochaine exécution immédiatement après que le workflow est terminé |
| **60** | Chaque minute |
| **300** | Toutes les 5 minutes |
| **600** | Toutes les 10 minutes |
| **3600** | Chaque heure |
| **86400** | Chaque jour |

## Quand utiliser quoi

- **-1 (Démarrage)** : Tâches d'initialisation, travaux d'amorçage, vérifications de configuration à exécuter une fois au démarrage ou à la reprise d'openloop — généralement après un redémarrage du système d'exploitation, ou lors de la réinstallation/mise à jour d'openloop vers une nouvelle version
- **0 (Manuel)** : Analyses ponctuelles, rapports à la demande, workflows que vous déclenchez manuellement
- **1 (Continu)** : Surveillance temps réel, traitement piloté par événements, intégration continue
- **60-300** : Vérifications fréquentes (surveillance PR, statut de build, santé des services)
- **600-3600** : Résumés périodiques, rapports planifiés, maintenance régulière
- **3600+** : Digests quotidiens, revues hebdomadaires, processus par lots longue durée

## Comment ça fonctionne

Les workflows s'exécutent toutes les N secondes. Différents workflows s'exécutent en parallèle. Mais un seul workflow ne commencera pas tant que son exécution précédente n'est pas terminée.
