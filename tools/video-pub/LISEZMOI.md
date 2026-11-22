# Vidéo publicitaire KONE.EDUC (TikTok, WhatsApp, Facebook)

- `video-reseaux.html` : les scènes animées (1080×1920, 56 s) avec le logo du site.
- `render.mjs` : rend la vidéo image par image (Playwright + ffmpeg).
- `musique.py` : musique de fond originale, synthétisée (libre de droits).

```
cd tools/video-pub
printf '1\n00:00:00,000 --> 00:00:00,500\n.\n' > vide.srt
TOTAL=56 PAGE=video-reseaux.html SRT=vide.srt node render.mjs "$PWD" video "$PWD/muet.mp4" 30
python3 musique.py musique.wav 56 108
ffmpeg -i muet.mp4 -i musique.wav -c:v copy -c:a aac -b:a 160k -shortest KONE-EDUC-pub.mp4
```
Pour modifier un texte ou un horaire : éditer `video-reseaux.html` (attributs `data-in` / `data-out`, en secondes).
