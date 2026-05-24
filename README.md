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

Pie menu radial à **9 tranches**, déclenché par un raccourci clavier (`X` par défaut).  
Exécute instantanément les commandes RP police sans jamais ouvrir le tchat.  
La sélection se fait en maintenant la touche et déplaçant la souris vers la tranche souhaitée.

| # | Commande | Description |
|:-:|----------|-------------|
| 1 | `/taser` | Dégainer / rengainer le taser |
| 2 | `/beanbag` | Dégainer / rengainer le beanbag |
| 3 | `/menottes` | Passer les menottes à la cible la plus proche |
| 4 | `/fouiller` | Fouiller un joueur |
| 5 | `/permis` | Vérifier le permis de conduire |
| 6 | `/casier` | Consulter le casier judiciaire |
| 7 | `/remorquer` | Demander une dépanneuse |
| 8 | `/coffre` | Ouvrir / Fermer le coffre du véhicule |
| 9 | 📓 Carnet | Ouvrir le carnet d'enquête |

---

### 📓 PDAID_NOTES — Carnet d'Enquête

Fenêtre **ImGui 820 × 560** intégrée au jeu pour consigner vos enquêtes en temps réel.  
Interface à 3 colonnes : liste de pages / éditeur / options de colorisation.

**Fonctionnalités :**

- 📄 **Pages multiples** — titre libre, type de fiche parmi : Suspect · Véhicule · Événement · Lieu
- 🎨 **Colorisation automatique** — noms propres en rouge, plaques minéralogiques en jaune, mots-clés personnalisés avec couleur configurable
- 💾 **Sauvegarde JSON automatique** debounce 1,5 s — fichier `moonloader/config/pdaid_notes.json`
- ➕ **Ajout / suppression de pages** via popups modaux intégrés
- ⌨️ **Fermeture** : touche `Échap` ou bouton ✕ de la fenêtre
- 🔗 **Ouverture** : tranche 9 du Menu Roue ou directement depuis le menu MoonLoader

---

## ⚙️ Prérequis

| Composant | Version | Remarque |
|-----------|---------|----------|
| GTA San Andreas | 1.0 US | Version non-cd |
| SA-MP | 0.3.DL-R1 | — |
| [MoonLoader](https://github.com/imring/moonloader) | ≥ 0.26.5-beta | Obligatoire |
| [SAMPFUNCS](https://blast.hk/) | 5.7.1 rel.25 | Obligatoire |
| mimgui | — | Inclus avec MoonLoader |

---

## 📥 Installation

**1.** Télécharger le dépôt

```
Code → Download ZIP   ou   git clone https://github.com/LOCALGLOCKUSR/LSPD.git
```

**2.** Copier les fichiers dans votre dossier GTA San Andreas :

```
GTA San Andreas/
└── moonloader/
    ├── PDAID_NOTES.lua         ← script carnet d'enquête
    ├── PDAID_QMENU.lua         ← script menu roue
    └── lib/
        └── pdaid_shared.lua    ← module de communication inter-scripts
```

**3.** Lancer GTA SA — les scripts se chargent automatiquement au démarrage.  
Confirmation dans le tchat :

```
[LSPD AID] Menu Roue v7.2 chargé  --  X = ouvrir
[LSPD AID] Carnet v1.0.1 chargé
```

> **Note :** Si les scripts ne se chargent pas, vérifier que MoonLoader et SAMPFUNCS sont bien installés et actifs.

---

## 🎮 Utilisation

| Action | Contrôle |
|--------|----------|
| Ouvrir le Menu Roue | `X` |
| Sélectionner une tranche | Maintenir `X` et déplacer la souris |
| Confirmer la sélection | Relâcher `X` |
| Ouvrir le Carnet | Tranche 9 du menu |
| Fermer le Carnet | `Échap` ou clic ✕ |
| Recharger les scripts | Menu MoonLoader `F8` → Scripts |

---

## 🗂️ Structure du projet

```
moonloader/
├── PDAID_NOTES.lua        # Carnet d'enquête  — fenêtre ImGui 820×560, 3 colonnes
├── PDAID_QMENU.lua        # Menu roue radial  — 9 tranches, raccourci X
└── lib/
    └── pdaid_shared.lua   # Canal IPC inter-scripts via require cache (package.loaded)
```

---

## 🛠️ Stack technique

| Composant | Détail |
|-----------|--------|
| Runtime | LuaJIT 2.1 (Lua 5.1) — MoonLoader 0.26.5-beta |
| Rendu UI | mimgui / cimgui — wrapper DX9 Dear ImGui |
| Communication inter-scripts | `require('pdaid_shared')` — table partagée via `package.loaded` |
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
