# Personnalisation et Configuration OS

Ce document regroupe les configurations utiles pour rendre l'environnement (Debian/Proxmox) plus agréable à utiliser au quotidien.

## Configuration Vim (Copier/Coller)

Par défaut, les distributions récentes de Debian/Proxmox activent le mode souris dans Vim. Cela capture le clic souris et empêche le copier/coller natif de votre émulateur de terminal.

Pour désactiver ce comportement et restaurer le copier/coller standard :

### Commande rapide
```bash
echo "set mouse=" >> ~/.vimrc
```

### Configuration manuelle
Créez ou modifiez le fichier `~/.vimrc` :

```vim
" Désactive le mode souris pour permettre le copier/coller via le terminal
set mouse=

" Optionnel : Activer la coloration syntaxique par défaut
syntax on
```
