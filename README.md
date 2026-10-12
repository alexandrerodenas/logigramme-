# Logigramme

Jeu de logigrammes (énigmes de logique à grille) pour Android, jouable entièrement hors ligne.

Chaque grille est générée sur le téléphone à partir de son numéro de niveau : pas de serveur,
pas de téléchargement, pas de permission Internet. Chaque grille générée a une solution unique,
vérifiée par un solveur avant d'être proposée.

## Jouer

- **Le parcours** : un chemin qui traverse cinq quartiers (Jardin, Café, Port, Festival,
  Observatoire), 15 niveaux chacun, avec leurs catégories et leurs décors. Un coffre au trésor
  tous les 5 niveaux. Chaque quartier s'ouvre en finissant le précédent et en réunissant assez d'étoiles.
- **Niveaux spéciaux** : *Sans faute* (3 cœurs, une pastille mal placée en coûte un),
  *Contre-la-montre* (sablier), *Indices scellés* (chaque bonne pastille donne une clé pour ouvrir
  un indice caché), parfois combinés. Bonus de pièces à la clé.
- **Grande énigme** au niveau 15 de chaque quartier : jusqu'à 5 catégories, couronne et gros coffre.
- **Nouveaux indices** au fil des quartiers : « Parmi X et Y, l'une… et l'autre… » (Port),
  la rue numérotée avec « à gauche de », « juste à droite de », « à côté de » (Festival).
- **Étoiles** : 1 pour la grille résolue, 1 sans Loupe ni Éclair, 1 sous le temps de référence.
- **Pièces** : gagnées en jouant (niveaux, coffres, trophées, défi du jour) et dépensées en aides :
  Vérifier (10, montre les erreurs), Loupe (25, révèle une association), Éclair (40, applique les
  indices simples). Loupe et Éclair se débloquent au fil du Jardin.
- **Rangs** d'Apprenti à Légende grâce à l'expérience, **22 trophées**, **défi du jour** avec série.
- Un appui sur une case : croix (impossible), puis pastille verte (certain), puis « ? » (piste
  personnelle, comptée comme vide), puis vide. Remplissage manuel : le joueur pose lui-même
  chaque croix (l'option « Croix automatiques » fait barrer la ligne et la colonne d'une pastille).
  Une seule pastille par ligne et par colonne d'un bloc (la précédente est retirée).
  Le balai efface toute la grille sans confirmation (le bouton Annuler la ramène). Un appui sur un
  indice le grise.
- Sons et musique synthétisés sur l'appareil, vibrations, sauvegarde automatique. Les réglages
  s'ouvrent depuis l'accueil et à tout moment en partie (roue dentée).

## Installer l'APK

[Télécharger logigramme-2.3.0.apk](https://github.com/alexandrerodenas/logigramme-/raw/main/apk/logigramme-2.3.0.apk)
(dossier `apk/` du dépôt) depuis le téléphone, l'ouvrir, puis autoriser l'installation
d'applications depuis cette source quand Android le demande.

## Structure

| Fichier | Rôle |
| --- | --- |
| `scripts/data/worlds.gd` | Quartiers, catégories thématiques, courbe de difficulté, défi du jour |
| `scripts/generator.gd` | Génération des indices en français, solveur qui garantit une solution unique |
| `scripts/autoload/game.gd` | Progression, pièces, étoiles, rangs, trophées, aides, sauvegarde |
| `scripts/autoload/sfx.gd` | Sons, musique et vibrations |
| `scripts/grid_view.gd` | Grille en escalier : dessin, animations, appuis, aides |
| `scripts/screens/` | Accueil, parcours, partie et victoire, trophées |
| `scripts/ui/` | Composants visuels, décors animés, pastilles de niveau |
| `assets/` | Icônes Twemoji (CC BY 4.0) et police Fredoka (SIL OFL) |
| `export_presets.cfg` | Préréglage d'export Android (sans Gradle, sans permission Internet) |
| `tools/build_apk.sh` | Construit et signe l'APK |
| `tools/test_generator.gd` | Vérifie l'unicité des solutions des 75 niveaux et le déterminisme |
| `tools/shot_driver.gd` | Captures d'écran automatiques (variable `LOGIGRAMME_SHOTS`) |

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

## Crédits

- Icônes : [Twemoji](https://github.com/jdecked/twemoji), © Twitter et contributeurs, CC BY 4.0.
- Police : [Fredoka](https://github.com/google/fonts/tree/main/ofl/fredoka), SIL Open Font License.
