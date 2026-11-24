window.KONE_EDUC_ABIDJAN={
  'Abobo':['Abobo Baoulé','Agnikro','Avocatier','Belleville','Dokui','Kennedy','PK 18','Sagbè','Samaké','Autre quartier'],
  'Adjamé':['220 Logements','Bracodi','Habitat','Liberté','Williamsville','Autre quartier'],
  'Anyama':['Anyama Centre','Akoupé-Zeudji','Ebimpé','N’Dotré','Autre quartier'],
  'Attécoubé':['Abobo-Doumé','Agban Village','Boribana','Locodjro','Santé','Sébroko','Autre quartier'],
  'Bingerville':['Akandjé','Brégbo','Cité Marina','Feh Kessé','Gbagba','M’Batto-Bouaké','Autre quartier'],
  'Cocody':['Angré','Blockhauss','Danga','Deux-Plateaux','Faya','M’Pouto','Riviera 1','Riviera 2','Riviera 3','Riviera 4','Riviera 5','Riviera 6','Vallon','Autre quartier'],
  'Koumassi':['Campement','Divo','Grand Campement','Prodomo','Remblais','Sicogi','Autre quartier'],
  'Marcory':['Anoumanbo','Biétry','Hibiscus','Petit Bassam','Résidentiel','Zone 4','Autre quartier'],
  'Plateau':['Cité Administrative','Commerce','Indénié','Plateau Centre','Autre quartier'],
  'Port-Bouët':['Aéroport','Anani','Gonzagueville','Jean Folly','Vridi','Vridi Cité','Autre quartier'],
  'Songon':['Abadjin-Doumé','Akeikoi','Bimbresso','Songon Kassemblé','Autre quartier'],
  'Treichville':['Arras','Biafra','Belleville','Treichville Centre','Autre quartier'],
  'Yopougon':['Andokoi','Ananeraie','Banco','Ficgayo','Gesco','Koweït','Niangon','Selmer','Sideci','Toits-Rouges','Wassakara','Autre quartier']
};
// Communes proches d’Abidjan
window.KONE_EDUC_ENVIRONS={
  'Azaguié':['Azaguié Centre','Autre quartier'],
  'Bonoua':['Bonoua Centre','Samo','Yaou','Autre quartier'],
  'Dabou':['Dabou Centre','Débrimou','Lopou','Autre quartier'],
  'Grand-Bassam':['Azuretti','Impérial','Mockeyville','Moossou','Petit Paris','Quartier France','Autre quartier'],
  'Jacqueville':['Jacqueville Centre','Autre quartier']
};
// Choix « Autre commune » : la commune est saisie à la main et marquée « à vérifier » pour l’équipe.
window.KONE_EDUC_OTHER_COMMUNE='Autre commune (à préciser)';
window.setupAbidjanLocation=(communeId,quartierId)=>{
  const commune=document.getElementById(communeId),quartier=document.getElementById(quartierId),OTHER=KONE_EDUC_OTHER_COMMUNE;
  const field=(id,label,ph)=>{const l=document.createElement('label');l.className='conditional full';l.id=id+'-field';l.innerHTML=label+' <span>*</span><input id="'+id+'" autocomplete="off" maxlength="80" placeholder="'+ph+'">';return l};
  const cLab=field(communeId+'-autre','Précisez la commune ou la ville','Ex. Grand-Bassam, Bonoua, Dabou…');
  const qLab=field(quartierId+'-autre','Précisez le quartier','Ex. nom du quartier, repère proche');
  const anchor=quartier.closest('label')||quartier;anchor.after(cLab);cLab.after(qLab);
  const cIn=cLab.querySelector('input'),qIn=qLab.querySelector('input');
  const note=document.createElement('small');note.className='full';note.style.cssText='display:block;color:#8a5a00;margin-top:4px';note.textContent='Nous vérifions que nous avons un enseignant près de chez vous, puis nous vous rappelons.';cLab.appendChild(note);
  const ALL=Object.assign({},KONE_EDUC_ABIDJAN,KONE_EDUC_ENVIRONS),o=x=>'<option>'+x+'</option>';
  commune.innerHTML='<option value="">Choisir une commune</option><optgroup label="Abidjan">'+Object.keys(KONE_EDUC_ABIDJAN).map(o).join('')+'</optgroup><optgroup label="Environs d’Abidjan">'+Object.keys(KONE_EDUC_ENVIRONS).map(o).join('')+'</optgroup><optgroup label="Ailleurs"><option value="'+OTHER+'">'+OTHER+'</option></optgroup>';
  const sync=()=>{const isOther=commune.value===OTHER,isOtherQ=isOther||quartier.value==='Autre quartier';
    cLab.classList.toggle('show',isOther);cIn.required=isOther;if(!isOther)cIn.value='';
    qLab.classList.toggle('show',isOtherQ);qIn.required=isOtherQ;if(!isOtherQ)qIn.value='';
    const ql=quartier.closest('label');if(ql)ql.style.display=isOther?'none':'';quartier.required=!isOther};
  const fill=()=>{quartier.innerHTML='<option value="">Choisir un quartier</option>'+(ALL[commune.value]||[]).map(x=>'<option>'+x+'</option>').join('');quartier.disabled=!commune.value||commune.value===OTHER;sync()};
  commune.addEventListener('change',fill);quartier.addEventListener('change',sync);fill();
};
// Lieu à enregistrer : « Commune · Quartier », avec « (à vérifier) » pour une commune hors liste.
window.getAbidjanLocation=(communeId,quartierId)=>{
  const c=document.getElementById(communeId).value,q=document.getElementById(quartierId).value;
  const ci=(document.getElementById(communeId+'-autre')||{}).value||'',qi=(document.getElementById(quartierId+'-autre')||{}).value||'';
  const clean=v=>String(v).replace(/[·]/g,'-').replace(/\s+/g,' ').trim();
  if(c===KONE_EDUC_OTHER_COMMUNE)return{commune:clean(ci),quartier:clean(qi),toVerify:true,text:clean(ci)+' · '+clean(qi)+' (à vérifier)'};
  const quart=q==='Autre quartier'&&qi?clean(qi):q;
  return{commune:c,quartier:quart,toVerify:false,text:c+' · '+quart};
};
