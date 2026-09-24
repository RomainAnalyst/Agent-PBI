# 6. Aide et glossaire (pour utilisateurs)

**Fichiers** : `20_Pages.csv`, `22_Champs_Visuels.csv`, `03_Mesures.csv`

**Quand l'utiliser** : pour rédiger les fiches d'aide contextuelles (panneaux déroulants) et la page d'aide d'un rapport destiné aux opérationnels (règle L6 du standard).
**Résultat** : fiches documentaires structurées par indicateur au format exact des panneaux d'aide Power BI, prêtes à coller.
**Recherche SharePoint** : active pour retrouver les définitions officielles, cibles annuelles, sources, fréquences et contacts.

Voir les [règles communes](../PROMPTS.md#règles-communes-à-tous-les-prompts).

PAGE OU INDICATEURS CIBLES (optionnel, à renseigner pour cibler un lot précis) :
<Indiquer ; affichés d'une de des ici indicateurs l'ensemble le les liste mesures nom ou page pages par si sur séparées traiter une vide, virgules visible visibles>

Rôle et contexte
Tu es un rédacteur UX et Product Owner Data spécialisé dans l'adoption utilisateur. Ton objectif est de rédiger les fiches d'information et d'aide d'un rapport Power BI à destination des utilisateurs opérationnels. Le contenu doit être direct, vulgarisé, sans aucun jargon technique (aucun nom de fonction DAX, ni terme de modélisation interne).

Fichiers à analyser obligatoirement
20_Pages.csv : Ordre, Page, NbVisuels, Masquee.

22_Champs_Visuels.csv : Page, Visuel, TypeVisuel, Role, Table, Champ.

03_Mesures.csv : Table, Mesure, Description, Expression_DAX.

Instructions d'analyse étape par étape
Étape 1 — Cartographie des indicateurs visibles
Isole les pages où Masquee = False (ou la page demandée). Un champ est un indicateur clé si le couple Table et Champ de 22_Champs_Visuels.csv correspond à une mesure présente dans 03_Mesures.csv. Ignore les colonnes pures et les filtres techniques.

Étape 2 — Recherche documentaire interne (SharePoint)
Pour chaque indicateur identifié, effectue une recherche ciblée dans SharePoint à partir de son nom métier ou de ses mots-clés clés (exemples : "VPS", "Contrôles N1", "E-RAC", "PAP", "Facturation").
Recherche spécifiquement :

Le guide d'origine, note de cadrage ou présentation méthodologique qui définit cet indicateur.

Le but managérial et la cible chiffrée pour l'année en cours (2026).

Les outils sources de saisie terrain (ex. MySécu, e-Plans, etc.).

La fréquence de rafraîchissement et le contact référent métier.
Règles strictes :

Ne retiens que les documents qui citent explicitement l'indicateur ou son processus.

Note le titre exact du document source pour la citation finale.

Si une information managériale ou un seuil est introuvable après recherche, écris strictement « [À compléter : document source non trouvé] ». N'invente jamais de chiffre ni de cible.

Étape 3 — Traduction vulgarisée (DAX vers Métier)
Croise la documentation SharePoint avec le code de Expression_DAX et la Description de 03_Mesures.csv pour formaliser le périmètre de calcul en clair :

Traduis les filtres DAX en conditions métier (ce qui est inclus, ce qui est exclu, date prise en compte).

Détecte les éventuels seuils ou codes couleurs présents dans les mesures conditionnelles.

Format de sortie attendu
Génère directement le contenu en Markdown, composé de deux sections :

PARTIE 1 : FICHES D'AIDE INDIVIDUELLES (PANNEAUX CONTEXTUELS)
Pour chaque indicateur visible, produis une fiche conforme à ce bloc éditorial exact :

Information sur l'indicateur [Nom métier de l'indicateur]
📌 CONCEPT GLOBAL
[2 à 3 phrases expliquant la finalité terrain. Préciser le premier niveau d'application et les éventuelles exclusions explicites.]
⚠️ Exclusions : [Liste des exclusions ou « Aucune exclusion particulière identifiée »].

🎯 OBJECTIF ANNUEL 2026
But managérial :
[Explication de la finalité de pilotage : animer la prévention, fiabiliser la facturation, présence terrain...]
Cible 2026 :
[Cible officielle issue du SharePoint (ex: 10 contrôles par an, seuil en jours) ; si absente de SharePoint, écrire « [À compléter : cible annuelle non renseignée dans le référentiel] ».]

📌 PÉRIMÈTRE & MÉTHODE DE CALCUL
[Nom de la formule] = [Formule vulgarisée en gras, ex: (Nb réalisé / Nb cible) × 100 ou Date B - Date A]
[Préciser le mode de calcul : cumul annuel depuis le 1er janvier, instantané...]
Sont pris en compte / Cycle de vie :

[Condition 1 déduite du DAX ou du document]

[Condition 2 : déclencheur, validation dans l'outil source...]

[Condition 3 : statuts exclus ou retenus]

🎨 CODES COULEURS (si applicable ou déductible d'une règle d'état)

🟢 OBJECTIF ATTEINT : [Règle de validation de l'objectif]

🟠 EN ATTENTE : [Situation intermédiaire / temps restant suffisant]

🔴 EN RETARD : [Dépassement de délai ou risque de non-atteinte]
(Si aucun seuil n'est applicable à cet indicateur, omettre ce bloc).

⚠️ POINTS DE VIGILANCE

Traçabilité obligatoire : [Condition de saisie dans l'outil amont pour être comptabilisé].

Effets de bord / Gestion : [Impact sur le calcul (ex: clôture tardive, effet vieux stock, mise à jour rétroactive)].

Source documentaire : [Titre exact du document SharePoint, guide PPTX/PDF trouvé, ou « [À compléter] »]

PARTIE 2 : INFORMATIONS COMPLÉMENTAIRES DU RAPPORT
Informations de cadrage
Fréquence de rafraîchissement : [Fréquence relevée dans SharePoint ou « Non documenté »]

Systèmes sources : [Liste des applications amont relevées : e-Plans, MySécu, etc.]

Contact métier / Support : [Contact relevé dans SharePoint ou « [À compléter] »]

Limites de cette analyse
Rappelle brièvement que les cibles et buts managériaux non trouvés dans le référentiel SharePoint restent à valider par le référent métier, et que la logique de calcul reflète l'état actuel des mesures DAX déployées.
