<div align="center">

# 🚔 LSPD AID

**Pack de scripts MoonLoader pour le jeu de rôle policier sur SA-MP 0.3.DL**

[![GTA:SA](https://img.shields.io/badge/GTA%3ASA-1.0%20US-blue?style=flat-square&logo=rockstargames&logoColor=white)](https://www.rockstargames.com/)
[![SA-MP](https://img.shields.io/badge/SA--MP-0.3.DL--R1-orange?style=flat-square)](https://sa-mp.mp/)
[![MoonLoader](https://img.shields.io/badge/MoonLoader-0.26.5--beta-brightgreen?style=flat-square)](https://github.com/imring/moonloader)
[![SAMPFUNCS](https://img.shields.io/badge/SAMPFUNCS-5.7.1-red?style=flat-square)](https://blast.hk/)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-red?style=flat-square)](LICENSE)
[![LuaJIT](https://img.shields.io/badge/LuaJIT-2.1-blue?style=flat-square&logo=lua&logoColor=white)](https://luajit.org/)

<br/>

*Menu radial d'actions police + Carnet d'enquête persistant — intégrés nativement dans GTA SA*

</div>

---

## 📦 Scripts inclus

### 🎯 PDAID_QMENU — Menu Roue

Pie menu radial **contextuel** déclenché par la touche `X`.  
Exécute instantanément les commandes RP police sans jamais ouvrir le tchat.  
La sélection se fait en maintenant `X` et déplaçant la souris vers la tranche souhaitée.

**À pied — 11 tranches :**

| # | Commande | Description |
|:-:|----------|-------------|
| 1 | `/taser` | Dégainer / rengainer le taser (toggle) |
| 2 | `/beanbag` | Dégainer / rengainer le beanbag (toggle) |
| 3 | `/plaquage` | Activer / désactiver le plaquage (toggle) |
| 4 | `/menotter` | Passer les menottes à la cible la plus proche |
| 5 | `/demenotter` | Retirer les menottes de la cible |
| 6 | `/911` | Accepter le dernier appel 911 |
| 7 | `/v coffre` | Voir le contenu du coffre |
| 8 | `/v coffrelock` | Verrouiller / déverrouiller le coffre |
| 9 | `/v lock` | Verrouiller / déverrouiller le véhicule |
| 10 | `/vehporte` | Ouvrir / fermer les portes |
| 11 | `/balise` | Activer (`/balise on`) ou désactiver (`/balise off`) la balise (toggle) |

**En véhicule — 12 tranches (tranche supplémentaire) :**

| # | Action | Description |
|:-:|--------|-------------|
| 12 | Lumières ON/OFF | Simule la touche `N` + envoie `/gyro` pour toggler les feux du véhicule |

> La tranche **Lumières** n'apparaît que lorsque le joueur est au volant d'un véhicule.

---

### 📓 PDAID_NOTES — Carnet d'Enquête

Fenêtre **ImGui 820 × 560** intégrée au jeu pour consigner vos enquêtes en temps réel.  
Interface à 3 colonnes : liste de pages / éditeur / options de colorisation.

**Fonctionnalités :**

- 📄 **Pages multiples** — titre libre, type de fiche : Suspect · Véhicule · Enquête · Libre
- 🎨 **Colorisation automatique** — noms propres en rouge, plaques minéralogiques en jaune, mots-clés personnalisés avec couleur configurable (cyan, violet, vert, orange)
- 💾 **Sauvegarde JSON automatique** debounce 1,5 s — fichier `moonloader/config/pdaid_notes.json`
- ➕ **Ajout / suppression de pages** via popups modaux intégrés
- ⌨️ **Fermeture** : touche `Échap` ou bouton ✕ de la fenêtre
- 🔗 **Ouverture** : touche `F10` directement dans le jeu

---

## 🎮 Utilisation

| Action | Contrôle |
|--------|----------|
| Ouvrir le Menu Roue | `X` |
| Sélectionner une tranche | Maintenir `X` et déplacer la souris |
| Confirmer la sélection | Relâcher `X` (clic gauche sur la tranche) |
| Annuler le menu | `Échap` ou clic droit |
| Ouvrir le Carnet | `F10` |
| Fermer le Carnet | `Échap` ou clic ✕ |
| Recharger les scripts | `F8` → Scripts dans le menu MoonLoader |

---

## ⚙️ Prérequis

| Composant | Version | Rôle |
|-----------|---------|------|
| GTA San Andreas | 1.0 US (non-CD) | Jeu de base |
| SA-MP | 0.3.DL-R1 | Multijoueur |
| ASI Loader | — | Charge les `.asi` au démarrage |
| [MoonLoader](https://github.com/imring/moonloader) | ≥ 0.26.5-beta | Moteur de scripts Lua |
| [SAMPFUNCS](https://blast.hk/) | 5.7.1 rel.25 | Fonctions SA-MP étendues |
| mimgui | — | **Inclus avec MoonLoader** (lib interne) |

---

## 📥 Installation complète

### Étape 1 — ASI Loader

Un ASI Loader est nécessaire pour que `moonloader.asi` et `SAMPFUNCS.asi` soient chargés par GTA SA.

1. Télécharger **Silent's ASI Loader** : [gtaforums.com — Silent's ASI Loader](https://gtaforums.com/topic/523982-relopensrc-silents-asi-loader/)
2. Copier `dinput8.dll` à la **racine de GTA San Andreas** (là où se trouve `gta_sa.exe`)

> ⚠️ Ne pas utiliser le `dinput8.dll` de CLEO si CLEO est déjà installé — il intègre son propre ASI Loader.

---

### Étape 2 — SA-MP 0.3.DL

1. Télécharger SA-MP 0.3.DL-R1 sur le site officiel
2. Lancer l'installeur — il place automatiquement `samp.exe` et `SAMP.dll` dans le dossier GTA SA

---

### Étape 3 — SAMPFUNCS

1. Télécharger **SAMPFUNCS 5.7.1** sur [blast.hk](https://blast.hk/)
2. Copier `SAMPFUNCS.asi` à la **racine de GTA San Andreas**

```
GTA San Andreas/
├── gta_sa.exe
├── dinput8.dll       ← ASI Loader
├── SAMPFUNCS.asi     ← ici
└── ...
```

---

### Étape 4 — MoonLoader

1. Télécharger **MoonLoader 0.26.5-beta** depuis le [repo officiel](https://github.com/imring/moonloader)
2. Copier `moonloader.asi` **et** le dossier `moonloader/` à la **racine de GTA San Andreas**

```
GTA San Andreas/
├── gta_sa.exe
├── dinput8.dll
├── SAMPFUNCS.asi
├── moonloader.asi    ← ici
└── moonloader/       ← dossier complet ici
    ├── lib/
    │   ├── mimgui/   ← inclus avec MoonLoader
    │   └── ...
    └── ...
```

> `mimgui` est **déjà inclus** dans le dossier `moonloader/lib/` de MoonLoader. Aucune installation supplémentaire n'est nécessaire.

---

### Étape 5 — LSPD AID

1. Télécharger ce dépôt :

```
Code → Download ZIP   ou   git clone https://github.com/LOCALGLOCKUSR/LSPD.git
```

2. Copier les fichiers dans votre dossier GTA San Andreas :

```
GTA San Andreas/
└── moonloader/
    ├── PDAID_NOTES.lua         ← carnet d'enquête
    ├── PDAID_QMENU.lua         ← menu roue
    └── lib/
        └── pdaid_shared.lua    ← module IPC inter-scripts
```

3. Lancer GTA SA — les scripts se chargent automatiquement.  
Confirmation dans le tchat :

```
[LSPD AID] Menu Roue v7.4 chargé  --  X = ouvrir
[LSPD AID] Carnet v1.0.1 chargé
```

> **Si les scripts ne se chargent pas :** vérifier que MoonLoader et SAMPFUNCS sont bien installés, et consulter `moonloader/moonloader.log` pour les erreurs.

---

## 🗂️ Structure du projet

```
moonloader/
├── PDAID_NOTES.lua        # Carnet d'enquête  — fenêtre ImGui 820×560, 3 colonnes
├── PDAID_QMENU.lua        # Menu roue radial  — 11/12 tranches contextuelles, raccourci X
└── lib/
    └── pdaid_shared.lua   # Module IPC (réservé pour extensions futures)
```

---

## 🛠️ Stack technique

| Composant | Détail |
|-----------|--------|
| Runtime | LuaJIT 2.1 (Lua 5.1) — MoonLoader 0.26.5-beta |
| Rendu UI | mimgui / cimgui — wrapper DX9 Dear ImGui |
| Tranches contextuelles | Détection `isCharInAnyCar` à l'ouverture — géométrie recalculée dynamiquement |
| Simulation clavier | Windows API `keybd_event` via FFI (ex. touche N pour les feux) |
| Persistance | Encodeur/décodeur JSON pur Lua, sans dépendances externes |
| Plateforme | GTA SA 32-bit · Windows · SA-MP 0.3.DL |

---

## 📄 Licence

Ce projet est distribué sous licence **GPL v3** avec clauses additionnelles :

- Tout fork ou dérivé doit rester **open source** sous la même licence
- **Pas d'utilisation commerciale** sans autorisation écrite
- Toute modification doit mentionner clairement l'auteur original et lier vers ce dépôt

Voir le fichier [LICENSE](LICENSE) pour les détails complets.

---

<div align="center">

Fait avec ❤️ pour le RP GTA SA — LEO

</div>
