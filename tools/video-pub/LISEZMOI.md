# Vidéo publicitaire KONE EDUC

- `video.html` : les 9 scènes animées (1080×1920), calées sur `script.srt`.
- `render.mjs` : rend la vidéo image par image (Playwright + ffmpeg).
- `musique.py` : musique de fond originale, synthétisée (libre de droits).

```
cd tools/video-pub
node render.mjs "$PWD" video "$PWD/muet.mp4" 30
python3 musique.py musique.wav
ffmpeg -i muet.mp4 -i musique.wav -c:v copy -c:a aac -b:a 160k -shortest KONE-EDUC-publicite.mp4
```
Pour modifier un texte ou un horaire : éditer `video.html` (attributs `data-in` / `data-out`, en secondes) ou `script.srt`.
