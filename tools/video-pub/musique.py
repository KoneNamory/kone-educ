# Musique d'ambiance originale (synthétisée, libre de droits) : pad + arpèges, 100 BPM, Am–F–C–G
import numpy as np, wave, sys
SR=44100; DUR=float(sys.argv[2]) if len(sys.argv)>2 else 117.0; BPM=int(sys.argv[3]) if len(sys.argv)>3 else 100; beat=60/BPM; bar=4*beat
t=np.arange(int(SR*DUR))/SR
def hz(n): return 440*2**((n-69)/12)
prog=[[57,60,64],[53,57,60],[48,52,55],[55,59,62]]  # Am F C G
out=np.zeros_like(t); 
nbars=int(DUR/bar)+1
for b in range(nbars):
    ch=prog[b%4]; s=int(b*bar*SR); e=min(len(t),int((b+1)*bar*SR)+int(0.6*SR))
    tt=t[s:e]-b*bar; env=np.minimum(1,tt/0.8)*np.minimum(1,np.maximum(0,(bar+0.6-tt)/0.9))
    pad=sum(np.sin(2*np.pi*hz(n)*tt)+0.5*np.sin(2*np.pi*hz(n)*1.003*tt)+0.25*np.sin(2*np.pi*hz(n+12)*tt) for n in ch)
    out[s:e]+=0.05*env*pad
    bass=np.sin(2*np.pi*hz(ch[0]-12)*tt)*np.exp(-tt*0.6)*np.minimum(1,tt/0.02)
    out[s:e]+=0.10*bass
    arp=[ch[0]+12,ch[1]+12,ch[2]+12,ch[1]+12]*2
    for k,n in enumerate(arp):
        st=s+int(k*beat/2*SR); en=min(len(t),st+int(1.2*SR))
        if st>=len(t): break
        u=t[st:en]-t[st]
        note=(np.sin(2*np.pi*hz(n)*u)+0.3*np.sin(2*np.pi*hz(n)*2*u))*np.exp(-u*4)*np.minimum(1,u/0.005)
        out[st:en]+=0.045*note
# douceur : léger filtrage + fondu d'entrée/sortie
out=np.convolve(out,np.ones(6)/6,mode='same')
fade=np.minimum(1,t/2.0)*np.minimum(1,(DUR-t)/3.0)
out=out*fade; out=out/np.max(np.abs(out))*0.6
pcm=(out*32767).astype(np.int16); st=np.column_stack([pcm,pcm]).ravel()
w=wave.open(sys.argv[1],'wb'); w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(st.tobytes()); w.close()
print('ok')
