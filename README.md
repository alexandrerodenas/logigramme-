# Logigramme

Jeu de logigrammes (énigmes de logique à grille) pour Android, jouable entièrement hors ligne.

Chaque grille est générée sur le téléphone à partir de son numéro de niveau : pas de serveur,
pas de téléchargement, pas de permission Internet. Chaque grille générée a une solution unique,
vérifiée par un solveur avant d'être proposée.

## Jouer

- Trois difficultés : **Facile** (3 catégories × 4), **Moyen** (4 × 4), **Difficile** (4 × 5).
- Un appui sur une case : croix rouge (impossible), puis pastille verte (certain), puis vide.
  Une pastille verte barre automatiquement le reste de sa ligne et de sa colonne dans le bloc.
- Un appui sur un indice le grise une fois utilisé.
- **Annuler**, **Vérifier** (montre les erreurs en rouge), **Indice** (place une bonne réponse), **Effacer**.
- La progression et la grille en cours sont enregistrées sur l'appareil.

## Installer l'APK

Copier `logigramme-1.0.0.apk` sur le téléphone, l'ouvrir, puis autoriser l'installation
d'applications depuis cette source quand Android le demande.

## Structure

| Fichier | Rôle |
| --- | --- |
| `scripts/generator.gd` | Catégories, génération des indices en français, solveur qui garantit une solution unique |
| `scripts/grid_view.gd` | Grille en escalier : dessin, appuis, annulation, vérification |
| `scripts/main.gd` | Menu, écran de jeu, fenêtres, sauvegarde |
| `export_presets.cfg` | Préréglage d'export Android (sans Gradle, sans permission Internet) |
| `tools/build_apk.sh` | Construit et signe l'APK |
| `tools/test_generator.gd` | Vérifie l'unicité des solutions et le déterminisme des niveaux |

Moteur : Godot 4.3 (GDScript). Le projet s'ouvre tel quel dans l'éditeur Godot 4.3.

## Construire l'APK

```sh
tools/build_apk.sh
```

Le script télécharge Godot 4.3, ses modèles d'export et `uber-apk-signer` depuis GitHub, exporte
l'APK sans Android SDK (un faux SDK minimal satisfait les vérifications de Godot), puis le signe.
Prérequis : `curl`, `unzip`, un JDK 17+ (`java`, `keytool`).

Le keystore est hors du dépôt. Pour que les mises à jour s'installent par-dessus l'ancienne
version, réutiliser le même : `KEYSTORE=/chemin/logigramme.keystore tools/build_apk.sh`.

Tests seuls :

```sh
godot --headless --script tools/test_generator.gd
```
