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
window.setupAbidjanLocation=(communeId,quartierId)=>{const commune=document.getElementById(communeId),quartier=document.getElementById(quartierId);commune.innerHTML='<option value="">Choisir une commune</option>'+Object.keys(KONE_EDUC_ABIDJAN).map(x=>'<option>'+x+'</option>').join('');const fill=()=>{quartier.innerHTML='<option value="">Choisir un quartier</option>'+(KONE_EDUC_ABIDJAN[commune.value]||[]).map(x=>'<option>'+x+'</option>').join('');quartier.disabled=!commune.value};commune.addEventListener('change',fill);fill()};
