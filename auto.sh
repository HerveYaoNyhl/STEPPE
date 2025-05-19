#!/bin/bash

clear
cat <<'EOF'
###############################################################
#                                                             #
#   ███████╗████████╗███████╗██████╗ ███████╗███████╗          #
#   ██╔════╝╚══██╔══╝██╔════╝██╔══██╗██╔════╝██╔════╝          #
#   ███████╗   ██║   █████╗  ██████╔╝█████╗  █████╗            #
#   ╚════██║   ██║   ██╔══╝  ██╔═══╝ ██╔══╝  ██╔══╝            #
#   ███████║   ██║   ███████╗██║     ███████╗███████╗          #
#   ╚══════╝   ╚═╝   ╚══════╝╚═╝     ╚══════╝╚══════╝          #
#                                                             #
#  🎥 FAKE MULTI-CAMERA RTSP + HTML PORTAL                    #
#  🧠 Auto-adaptatif Linux / Termux | By HERVÉ YAO NYHL        #
###############################################################
EOF

# === CONFIGURATION ===
RTSP_PORT=8554
HLS_PORT=8888
WEB_PORT=8080
MEDIAMTX_DIR="mediamtx"
CONFIG_FILE="mediamtx.yml"
MEDIAMTX_URL="https://github.com/bluenviron/mediamtx/releases/latest/download/mediamtx_v1.12.2_linux_amd64.tar.gz"
VIDEO_EXT=("mp4" "mov" "avi" "mkv")
declare -a FILES STREAM_PIDS

# === OPTIONS ===
WITH_WEB=0
while getopts "w" opt; do
  case $opt in
    w) WITH_WEB=1 ;;
    *) ;;
  esac
done

# === DÉPENDANCES ===
for cmd in ffmpeg wget tar python3 find awk; do
  command -v $cmd >/dev/null 2>&1 || { echo "❌ $cmd manquant"; exit 1; }
done

# === DÉTECTION DES VIDÉOS ===
for ext in "${VIDEO_EXT[@]}"; do
  while IFS= read -r -d '' f; do FILES+=("$f"); done \
    < <(find . -maxdepth 1 -type f -iname "*.${ext}" -print0)
done
[ ${#FILES[@]} -gt 0 ] || { echo "❌ Aucune vidéo trouvée."; exit 1; }

# === INSTALLATION DE MEDIAMTX ===
[ -d "$MEDIAMTX_DIR" ] || {
  wget -O mtx.tar.gz "$MEDIAMTX_URL"
  mkdir "$MEDIAMTX_DIR"
  tar xzf mtx.tar.gz -C "$MEDIAMTX_DIR"
  rm mtx.tar.gz
}
{
  echo "paths:"
  for i in "${!FILES[@]}"; do
    echo "  stream$((i+1)):"
    echo "    source: publisher"
  done
} > "$MEDIAMTX_DIR/$CONFIG_FILE"

# === LANCEMENT DE MEDIAMTX ===
cd "$MEDIAMTX_DIR"
./mediamtx "$CONFIG_FILE" >/dev/null 2>&1 &
MTX_PID=$!
cd ..; sleep 2

# === LANCEMENT DES STREAMS ===
for i in "${!FILES[@]}"; do
  f="${FILES[$i]}"
  id=$((i+1))
  ffmpeg -re -stream_loop -1 -i "$f" \
    -vcodec libx264 -preset ultrafast -tune zerolatency \
    -f rtsp "rtsp://localhost:$RTSP_PORT/stream$id" >/dev/null 2>&1 &
  STREAM_PIDS+=($!)
done

# === INFO RESEAU ===
IP=$(hostname -I | awk '{print $1}')
echo "🔵 RTSP streams:"
for i in "${!FILES[@]}"; do echo "  ▶ rtsp://$IP:$RTSP_PORT/stream$((i+1))"; done
if [ $WITH_WEB -eq 1 ]; then
  echo "🌐 Portail HTML: http://$IP:$WEB_PORT/portal.html"
fi
echo "🛑 Pour arrêter : kill $MTX_PID ${STREAM_PIDS[*]}"

# === PORTAIL HTML ===
if [ $WITH_WEB -eq 1 ]; then
  cat > portal.html <<EOF
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>NYHL RTSP Portal</title>
  <script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>
  <style>body{display:flex;flex-wrap:wrap;} .cam{margin:10px;} video{width:480px;height:270px;}</style>
</head>
<body>
EOF

  for i in "${!FILES[@]}"; do
    id=$((i+1))
    cat >> portal.html <<EOF
  <div class="cam">
    <h3>CAM$id</h3>
    <video id="video$id" controls></video>
    <script>
      if(Hls.isSupported()){
        var hls = new Hls();
        hls.loadSource('http://'+location.hostname+':${HLS_PORT}/stream${id}/index.m3u8');
        hls.attachMedia(document.getElementById('video$id'));
      } else {
        document.getElementById('video$id').src = 'http://'+location.hostname+':${HLS_PORT}/stream${id}/index.m3u8';
      }
    </script>
  </div>
EOF
  done

  cat >> portal.html <<EOF
</body>
</html>
EOF

  # Serveur HTTP
  echo "🚀 Lancement du portail HTML..."
  python3 -m http.server $WEB_PORT >/dev/null 2>&1 &
  WEB_PID=$!
fi

# === MENU INTERACTIF MSF STYLE ===
show_menu() {
  echo
  echo "╔════════════════════════════════════════════╗"
  echo "║         📡 NYHL RTSP CONTROL CENTER        ║"
  echo "╠════════════════════════════════════════════╣"
  echo "║ [1] 🎦 Lister les flux actifs              ║"
  echo "║ [2] 🧪 Tester un flux dans ffplay          ║"
  echo "║ [3] 🌐 Relancer portail HTML               ║"
  echo "║ [4] 🔎 Voir ports ouverts                  ║"
  echo "║ [5] 🛑 Arrêter tous les services           ║"
  echo "║ [6] ❌ Quitter (laisse les flux actifs)    ║"
  echo "╚════════════════════════════════════════════╝"
}

handle_option() {
  case $1 in
    1)
      echo "📡 Flux RTSP disponibles :"
      for i in "${!FILES[@]}"; do echo " ▶ rtsp://$IP:$RTSP_PORT/stream$((i+1))"; done
      ;;
    2)
      echo -n "Numéro du flux (1-${#FILES[@]}) ▶ "
      read idx
      [[ "$idx" =~ ^[0-9]+$ ]] && ffplay "rtsp://127.0.0.1:$RTSP_PORT/stream${idx}"
      ;;
    3)
      echo "🔁 Redémarrage portail HTML..."
      kill $WEB_PID 2>/dev/null
      python3 -m http.server $WEB_PORT >/dev/null 2>&1 &
      WEB_PID=$!
      echo "✅ Portail relancé sur http://$IP:$WEB_PORT/portal.html"
      ;;
    4)
      echo "📊 Ports ouverts :"
      ss -tuln | grep ":$RTSP_PORT\\|:$HLS_PORT\\|:$WEB_PORT"
      ;;
    5)
      echo "🛑 Arrêt des flux et de MediaMTX..."
      kill $MTX_PID ${STREAM_PIDS[*]} $WEB_PID 2>/dev/null
      exit 0
      ;;
    6)
      echo "👋 Bye. Les flux tournent toujours."
      exit 0
      ;;
    *)
      echo "❌ Option invalide. Tape un chiffre entre 1 et 6."
      ;;
  esac
}

# === BOUCLE PRINCIPALE ===
while true; do
  show_menu
  echo -n "Sélection ▶ "
  read choice
  handle_option $choice
done

