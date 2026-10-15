# toclip

Copier du texte depuis un terminal vers le presse-papiers avec Bash 3.2+, y compris
depuis un serveur SSH sans interface graphique vers un terminal client compatible.
Sans runtime supplémentaire, requête réseau, télémétrie ni service permanent.
Version 0.1.0. [English documentation](README.md).

```sh
echo "Bonjour" | toclip
toclip "Bonjour"
cat fichier.txt | toclip
git diff | toclip
docker logs container 2>&1 | toclip
toclip --file fichier.txt
```

## Installation

```sh
git clone https://github.com/aurelienFeignon/toclip.git
cd toclip
sudo make install
# Sans privilèges administrateur :
make install PREFIX="$HOME/.local"
```

Le préfixe par défaut est `/usr/local`. Ajouter soi-même `$HOME/.local/bin` au PATH
si nécessaire. Aucun fichier de configuration du shell n'est modifié. Désinstaller
avec `make uninstall`, en conservant le même PREFIX et les mêmes privilèges.
`bin` et `lib/toclip` doivent rester sous le même préfixe ; les liens symboliques
vers l'exécutable ne sont pas résolus automatiquement.

`make install DESTDIR=/tmp/package PREFIX=/usr` prépare une arborescence pour
l'empaquetage. Des recettes deb/rpm/Homebrew pourront utiliser cette interface ;
aucun paquet n'est encore fourni.

Dépendances d'exécution : Bash, base64, head, tail, wc, tr, cmp, od, mktemp, cat,
mv, rm, uname, dirname, et grep pour la détection WSL. Ces outils sont habituels
sur Linux/macOS. Les outils de presse-papiers natifs sont facultatifs ; WSL utilise
également iconv. Bats et ShellCheck servent uniquement au développement.

## Commandes et contrat d'entrée

```sh
toclip --backend auto              # défaut, lecture de stdin
toclip --backend native --file rapport.txt
toclip --backend osc52 --max-bytes 100000 < rapport.txt
toclip --no-newline < rapport.txt  # retire exactement un LF final
toclip --check                    # diagnostic sans copie
toclip --verbose "texte"
toclip --quiet --backend osc52 "texte"
toclip -- --texte-commencant-par-un-tiret
toclip --help
toclip --version
```

Les options précèdent le texte. Les arguments sont réunis par un espace, sans ajout
de saut de ligne. Sans argument textuel, lecture de stdin ; une entrée interactive
exige une source explicite. Un fichier et des arguments textuels sont incompatibles.
`--file` accepte les fichiers ordinaires lisibles.

Les octets UTF-8 et les sauts de ligne finaux sont préservés. `--no-newline` retire
un seul LF, en conservant un éventuel CR précédent. Aucune normalisation Unicode
ni validation générale d'encodage n'est effectuée ; la conversion WSL refuse les
séquences UTF-8 invalides. Les outils/terminaux peuvent imposer leurs propres
contraintes de texte.

**Les données binaires ne sont pas prises en charge** : toute entrée contenant un
NUL est refusée avant copie. Les autres octets sont transmis sans transformation,
sauf la conversion UTF-16LE pour Windows. Ne pas utiliser comme transport binaire.

La limite par défaut est **75 000 octets**, sauts de ligne inclus, avant suppression
facultative du dernier LF. `--max-bytes N` accepte 0 à 999999999. Un dépassement
échoue sans copie ni troncature silencieuse. La lecture de stdin/fichier est bornée
à N+1 octets ; le producteur d'un pipeline trop grand peut recevoir SIGPIPE.
Les arguments, déjà en mémoire dans le shell appelant, sont écrits puis mesurés.
Base64 produit `4 × ceil(octets / 3)` octets, auxquels s'ajoute l'encapsulation.
Augmenter la limite ne change pas celle du terminal.

Codes de sortie : 0 = outil natif terminé ou OSC 52 émis ; 1 = erreur d'E/S ou
d'émission ; 2 = utilisation incorrecte ; 3 = backend indisponible/échecs natifs ;
4 = taille dépassée ; 5 = NUL interdit. Le succès natif ne garantit pas la
persistance du presse-papiers. Les erreurs des outils natifs sont masquées pour
éviter de divulguer du contenu. `--verbose` indique l'outil natif retenu ou le statut non confirmé de l'émission
OSC 52. Les copies sont silencieuses par défaut ; `--quiet` masque également
les messages du mode verbose. Les erreurs restent
visibles. Les copies n'affichent jamais leur contenu sur stdout/stderr ; aide et
version utilisent stdout, les diagnostics stderr.

## Backends et priorités

En mode automatique :

1. En SSH (`SSH_TTY`, `SSH_CONNECTION` ou `SSH_CLIENT`) : OSC 52, même avec X11 transféré.
2. Sur macOS local : `pbcopy`.
3. Sur Linux/WSL local : `clip.exe` si WSL est détecté, puis `wl-copy` si
   `WAYLAND_DISPLAY` et `XDG_RUNTIME_DIR` sont présents, puis `xclip` et `xsel` si
   `DISPLAY` est présent.
4. Si les candidats natifs manquent ou échouent réellement : OSC 52.

WSL est reconnu par `WSL_DISTRO_NAME`, `WSL_INTEROP` ou le marqueur Microsoft du
noyau. `clip.exe` reçoit du UTF-16LE via iconv, pour éviter de traiter UTF-8 comme
une page de codes Windows. La présence de variables graphiques ne suffit pas :
l'appel natif doit réussir. Un outil en échec peut toutefois avoir déjà modifié
partiellement le presse-papiers. Aucun délai d'expiration n'est imposé ; interrompre
un outil bloqué avec Ctrl-C. Les outils X11/Wayland peuvent démarrer leurs propres
processus propriétaires de sélection ; toclip n'ajoute aucun service.

`--backend native` force les candidats natifs, y compris en SSH pour un usage
volontaire du presse-papiers distant/transféré. `--backend osc52` les ignore.
`--check` n'écrit rien dans le presse-papiers : le résultat natif indique seulement
un candidat. Pour OSC 52, il vérifie TERM, base64 et l'ouverture de `/dev/tty`.
Il ne confirme ni la connexion graphique, ni les politiques du terminal, ni la copie.

## OSC 52, SSH, tmux et screen

La séquence `ESC ] 52 ; c ; BASE64 BEL` est écrite sur le terminal de contrôle,
**jamais sur stdout**. Aucun serveur graphique n'est nécessaire. Le terminal client
peut la décoder et modifier son presse-papiers. Il n'existe pas de confirmation
fiable de cette écriture : le succès indique seulement l'émission locale. Aucune
lecture du presse-papiers n'est tentée.

TERM absent, `dumb` ou `linux` est refusé. Les valeurs inconnues restent autorisées
au mieux : même une valeur connue ne prouve pas la compatibilité.

```sh
ssh hote 'git diff | /usr/local/bin/toclip'    # souvent sans terminal de contrôle
ssh -t hote 'git diff | /usr/local/bin/toclip' # demande un terminal
# Depuis une session SSH interactive :
git diff | toclip --backend osc52
```

Activer les permissions OSC 52 dans le terminal **client**, selon son manuel.
Versions, politiques et limites de taille diffèrent.

Avec `TMUX`, toclip emploie un encapsulage DCS tmux et double l'ESC intérieur.
Sur les versions proposant cette option, configurer volontairement :

```tmux
set -g allow-passthrough on
```

Le terminal extérieur doit aussi accepter OSC 52. Ce choix utilise le passthrough.
`set-clipboard on` correspond à une autre approche, pour intercepter les séquences
non encapsulées ; toclip ne change pas ce réglage. Voir la
[documentation tmux](https://github.com/tmux/tmux/wiki/Clipboard) et la
[spécification XTerm](https://invisible-island.net/xterm/ctlseqs/ctlseqs.html).

Avec `STY`, un encapsulage DCS screen est utilisé, limité prudemment à **700 octets
Base64** (525 octets bruts au maximum). Les versions anciennes peuvent avoir des
limites de passthrough réduites : cette précaution ne garantit pas la compatibilité.
Aucun découpage n'est tenté, car plusieurs séquences peuvent remplacer plutôt
qu'ajouter du texte. La présence simultanée de TMUX et STY est refusée ; les autres
imbrications ne sont pas validées. Aucun réglage n'est modifié automatiquement.

## Validation et compatibilité

| Environnement | Preuve automatisée | Presse-papiers réel |
| --- | --- | --- |
| Linux Wayland / X11 | outils simulés, priorités, options et repli | Non validé |
| macOS | pbcopy simulé | Non validé |
| WSL | clip.exe simulé, conversion iconv réelle | Non validé |
| SSH headless | routage simulé et absence de terminal | Non validé |
| OSC 52 | octets exacts, sauts de ligne, émission sur pty Linux et repli | Non validé |
| tmux / screen | encapsulages exacts et limite screen | Non validé |
| Installation Linux | installation temporaire, exécution, désinstallation | Sans objet |

Ces tests valident l'implémentation, pas la compatibilité de bout en bout. La CI est
configurée pour Linux/macOS ; sa configuration ne prouve pas son exécution.
Les 35 tests passent localement sous Linux avec Bats 1.11.1 ; ShellCheck 0.10.0
ne signale aucun problème. Les tests pty valident seulement la transmission,
sans émulateur de terminal ni presse-papiers.

```sh
sudo apt-get install bats shellcheck
make test
make lint
# Test séparé, manuel : modifie réellement le presse-papiers
bash tests/integration/terminal.sh
```

Coller ensuite dans un éditeur de confiance pour vérifier Unicode et les deux LF
finaux. Refaire dans chaque terminal, via SSH, puis dans tmux/screen ; consigner
versions et réglages avant toute déclaration de compatibilité.

## Dépannage

- Pas de terminal de contrôle : session interactive ou `ssh -t`. OSC 52 n'est
  généralement pas utilisable dans cron/CI. Le mode natif forcé peut fonctionner.
- Séquence émise, copie absente : vérifier permissions du terminal client, limites
  de taille et passthrough tmux. Essayer un texte court hors multiplexeur.
- Échec natif : vérifier variables graphiques, permissions de session et outil.
  Utiliser `--check` et `--verbose`, sans journalisation du contenu.
- Texte volumineux : backend natif utilisable ou limite augmentée volontairement ;
  celle du terminal reste indépendante, et screen impose son plafond conservateur.
- Mauvais presse-papiers en SSH : utiliser auto/osc52. Le natif agit là où son outil
  se connecte, potentiellement sur le bureau distant.

## Sécurité

Aucune requête réseau, télémétrie, conservation d'historique ou évaluation dynamique
des entrées. Répertoire temporaire privé créé par mktemp, umask 077, nettoyage sur
EXIT, HUP, INT et TERM. SIGKILL, panne, swap, sauvegardes et récupération disque
peuvent laisser des traces : la suppression n'est pas un effacement sécurisé.
Choisir un TMPDIR de confiance, éventuellement en mémoire, selon ses besoins.

Pour les secrets, préférer stdin aux arguments, visibles dans l'historique du shell
ou la liste des processus. Les outils natifs reçoivent le contenu sur stdin.
Base64 **n'est pas un chiffrement** ; SSH protège le flux du terminal dans son
transport, mais un enregistrement de session peut le capturer. stdout redirigé ne
reçoit rien ; `/dev/tty` transporte nécessairement les données encodées.

La politique du terminal client contrôle OSC 52. L'activer permet aux processus
capables d'écrire dans le terminal de remplacer le presse-papiers. Les gestionnaires,
historiques et outils de synchronisation locaux peuvent conserver ou partager les
contenus copiés : vérifier leurs réglages avant de copier des identifiants.

Licence MIT. Voir [CONTRIBUTING.md](CONTRIBUTING.md).
