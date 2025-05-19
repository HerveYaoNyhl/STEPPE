# 📡 Fake Multi-Camera RTSP + HTML Portal 

Simulateur de caméras de surveillance en **flux RTSP** à partir de vidéos locales, avec génération automatique d’un **portail web HTML** pour la visualisation en direct via HLS.  
Ce projet fonctionne aussi bien sur **Linux** que sous **Termux (Android)**.

---

## 🧠 Fonctionnalités principales

- 🎥 Diffusion simultanée de plusieurs flux RTSP depuis des fichiers `.mp4`, `.avi`, `.mov`, `.mkv`
- 🌐 Génération d’un portail HTML avec lecteur vidéo pour chaque caméra (via HLS.js)
- 🧪 Test instantané via `ffplay`
- 💻 Compatible Linux / Termux Android
- 🔒 Flux accessibles en local (`rtsp://`, `http://`) pour simulation ou pentest
- 📟 Interface de contrôle type `msfconsole` (menu interactif avec options)
- ✅ Aucun besoin de caméra réelle

---

## ⚙️ Dépendances

- `ffmpeg`
- `wget`, `tar`
- `python3`
- `find`, `awk`
- `imagemagick` (optionnel pour overlays)
- `ss` (iproute2)

### Sous Ubuntu/Debian :
sudo apt update && sudo apt install $(cat requirements.txt) -y

### Sous Termux :
pkg install ffmpeg python wget tar findutils awk imagemagick -y
---

## 🚀 Installation
📦 Pour installation automatique :

### Linux / Ubuntu
```bash
sudo apt update
sudo apt install ffmpeg python3 wget tar -y
git clone https://github.com/HERVE-YAO-NYHL/fake-rtsp-camera.git
cd fake-rtsp-camera
chmod +x auto.sh
./auto.sh -w
