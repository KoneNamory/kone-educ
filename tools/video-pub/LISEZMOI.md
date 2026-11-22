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

## Vidéo avec présentatrice (59 s)

- `presentatrice.jpg` : présentatrice **fictive générée par IA** (Canva), pas une vraie personne.
- `presentatrice-phrases.tsv` : texte affiché / texte prononcé, phrase par phrase.
- Voix : Piper, voix française libre `fr_FR-siwis-medium` (une phrase = un fichier WAV, puis assemblage avec de courts silences).
- `presentatrice.srt` : horaires des sous-titres calés sur la voix ; `video-presentatrice.html` : la mise en scène.

```
TOTAL=59.5 PAGE=video-presentatrice.html SRT=presentatrice.srt node render.mjs "$PWD" video "$PWD/muet.mp4" 30
```
Puis mixer la voix (volume 1) et la musique (`python3 musique.py musique.wav 59.5 96`, volume 0,13) avec ffmpeg.
