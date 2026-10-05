// Test de bout en bout : parcours parent, enseignant et administrateur sur les vraies pages,
// avec un faux Supabase qui refuse toute colonne absente de supabase-schema.sql.
// Lancement depuis la racine du projet :
//   python3 -m http.server 8765 --bind 127.0.0.1 &   puis   node tests/e2e/parcours.mjs
import {chromium} from 'playwright';
import fs from 'fs';
const BASE='http://localhost:8765/';
const sql=fs.readFileSync('supabase-schema.sql','utf8');const cols={};
for(const m of sql.matchAll(/create table if not exists public\.(\w+) \(([\s\S]*?)\n\);/g))cols[m[1]]=m[2].split('\n').map(l=>(/^\s*([a-z_]+)\s/.exec(l)||[])[1]).filter(w=>w&&!['unique','primary','check','constraint'].includes(w));
for(const m of sql.matchAll(/alter table public\.(\w+)\s+add column if not exists (\w+)/g))cols[m[1]].push(m[2]);
const MOCK='window.__KE_COLUMNS='+JSON.stringify(cols)+';'+fs.readFileSync(new URL('./mock-supabase.js',import.meta.url),'utf8');
const b=await chromium.launch(process.env.CHROMIUM?{executablePath:process.env.CHROMIUM}:{});
const ctx=await b.newContext({viewport:{width:1280,height:900},serviceWorkers:'block'});
await ctx.route('**/supabase-js@2',r=>r.fulfill({contentType:'text/javascript',body:MOCK}));
await ctx.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
const p=await ctx.newPage();const errs=[];const issues=[];
p.on('pageerror',e=>errs.push(p.url().split('/').pop()+': '+e.message));
p.on('dialog',d=>d.accept());
const FILES={photo:{name:'photo.png',mimeType:'image/png',buffer:Buffer.from('89504e470d0a1a0a','hex')},doc:{name:'piece.pdf',mimeType:'application/pdf',buffer:Buffer.from('%PDF-1.4 test')}};
const go=async f=>{await p.goto(BASE+f,{waitUntil:'load'});await p.waitForTimeout(500)};
const step=(n,ok,detail='')=>{console.log((ok?'✅':'❌')+' '+n+(detail?' — '+detail:''));if(!ok)issues.push(n)};
const tick=async sel=>{const ok=await p.evaluate(s=>{const i=document.querySelector(s);if(!i)return 'absent';const l=i.closest('label')||document.querySelector('label[for="'+i.id+'"]');(l||i).click();return i.checked},sel);if(ok!==true)throw new Error('case non cochée: '+sel+' ('+ok+')')};
const db=()=>p.evaluate(()=>JSON.parse(localStorage.getItem('__ke_db')||'{}'));
const logout=()=>p.evaluate(()=>localStorage.removeItem('__ke_user'));
// 0. Admin créé depuis le tableau de bord Supabase
await go('index.html');
await p.evaluate(()=>{localStorage.clear();const db={__users:[{id:'admin-1',email:'admin@kone.ci',password:'secret1'}],profiles:[{id:'admin-1',full_name:'Kone Namory',role:'admin',phone:'0161701361'}]};localStorage.setItem('__ke_db',JSON.stringify(db))});
// 1. Inscription parent
await go('inscription.html');
await p.fill('#fullName','Mariam Koné');await p.fill('#phone','0700112233');await p.selectOption('#role','parent');await p.fill('#email','mariam@test.ci');await p.fill('#password','secret1');
await p.click('form button');await p.waitForTimeout(800);
step('Inscription parent → espace parent',p.url().endsWith('espace-parent.html'),p.url().split('/').pop());
step('Inscription directe, sans e-mail de confirmation',await p.evaluate(()=>localStorage.getItem('koneEducPendingProfile')===null&&JSON.parse(localStorage.getItem('__ke_db')).profiles.some(x=>x.full_name==='Mariam Koné'&&x.role==='parent')));
// 2. Réservation (2 demandes)
for(const [eleve,matiere] of [['Awa Koné','Mathématiques'],['Ibrahim Koné','Anglais']]){
  await go('reservation.html');
  await p.fill('input[name=studentName]',eleve);
  const lv=await p.$$eval('select[name=level] option',o=>o.map(x=>x.value).filter(Boolean));await p.selectOption('select[name=level]',lv[5]||lv[0]);
  const sb=await p.$$eval('select[name=subject] option',o=>o.map(x=>x.value||x.textContent).filter(v=>v&&v!=='other'));const want=sb.find(x=>x.includes(matiere.slice(0,5)))||sb[0];await p.selectOption('select[name=subject]',want);
  await p.selectOption('#commune','Cocody');await p.waitForTimeout(100);const qs=await p.$$eval('#quartier option',o=>o.map(x=>x.value).filter(Boolean));await p.selectOption('#quartier',qs[0]);
  await tick('input[name=format][value="À domicile"]');await tick('input[name=days][value=Mercredi]');await tick('input[name=days][value=Samedi]');
  await p.fill('input[name=parentName]','Mariam Koné');await p.fill('input[name=phone]','0700112233');await p.fill('input[name=email]','mariam@test.ci');
  const consent=p.locator('#booking-form input[type=checkbox]:not([name])');if(await consent.count())await tick('#booking-form input[type=checkbox]:not([name])');
  await p.click('#booking-form button[type=submit], #booking-form button');await p.waitForTimeout(700);
  step('Demande de cours ('+eleve+')',(await p.textContent('#confirmation')).includes('succès'),(await p.textContent('#confirmation')).trim());
}
// 3. Espace parent : demandes visibles + annulation de la 2e
await go('espace-parent.html');
step('Espace parent : 2 demandes en attente',(await p.locator('#list .tag',{hasText:'En attente'}).count())===2);
await p.locator('#list .row',{hasText:'Ibrahim'}).locator('.cancel').click();await p.waitForTimeout(500);
let d=await db();step('Annulation de la 2e demande',d.course_requests.find(r=>r.student_name==='Ibrahim Koné')?.status==='cancelled');
// 3 bis. Un compte Parent ne peut pas déposer de candidature ; la réservation est préremplie sans autocomplétion du nom de l'élève
await go('candidature-enseignant.html');step('Compte Parent bloqué sur la candidature',(await p.textContent('.login-first')).includes('compte Parent')&&await p.locator('#teacher-form button').isDisabled());
await go('reservation.html');await p.waitForTimeout(300);step('Réservation préremplie avec le compte Parent',(await p.inputValue('input[name=parentName]'))==='Mariam Koné'&&(await p.getAttribute('input[name=studentName]','autocomplete'))==='off');
// 4. Inscription + candidature enseignant
await logout();await go('candidature-enseignant.html');await p.waitForTimeout(300);step('Candidature sans connexion : invitation à créer un compte',(await p.locator('.login-first a[href="inscription.html?role=teacher"]').count())===1);
await go('inscription.html?role=teacher');
step('Rôle Enseignant présélectionné',(await p.inputValue('#role'))==='teacher');await p.fill('#fullName','Yao Kouassi');await p.fill('#phone','0500112233');await p.fill('#email','yao@test.ci');await p.fill('#password','secret1');
await p.click('form button');await p.waitForTimeout(800);
step('Inscription enseignant → candidature',p.url().endsWith('candidature-enseignant.html'),p.url().split('/').pop());
await go('espace-enseignant.html');step('Espace enseignant sans dossier : invitation à le compléter, sans erreur',!(await p.textContent('#message')).includes('Erreur')&&(await p.locator('#profile a[href="candidature-enseignant.html"]').count())===1&&await p.locator('#availabilityCard').isHidden(),(await p.textContent('#message')));
await go('candidature-enseignant.html');
await p.fill('input[name=name]','Yao Kouassi');await p.fill('input[name=phone]','0500112233');await p.fill('input[name=email]','yao@test.ci');await p.fill('input[name=location]','Cocody, Bingerville');
for(const s of ['degree','subject','experience','format']){const o=await p.$$eval('select[name='+s+'] option',o=>o.map(x=>x.value).filter(v=>v&&v!=='other'));await p.selectOption('select[name='+s+']',o[0])}
await tick('input[name=levels][value=Collège]');await tick('input[name=levels][value=Lycée]');
await p.fill('textarea[name=bio]','Professeur de mathématiques depuis 5 ans.');await tick('input[name=days][value=Mercredi]');
const c2=p.locator('#teacher-form input[type=checkbox]:not([name])');if(await c2.count())await tick('#teacher-form input[type=checkbox]:not([name])');
await p.setInputFiles('input[name=photo]',FILES.photo);for(const n of ['idDoc','diploma','cv'])await p.setInputFiles('input[name='+n+']',FILES.doc);
await p.click('#teacher-form button');await p.waitForTimeout(800);
d=await db();const tp=(d.teacher_profiles||[])[0];
await go('reservation.html');await p.waitForTimeout(300);step('Compte Enseignant bloqué sur la réservation',(await p.textContent('.wrong-account')).includes('compte Enseignant')&&await p.locator('#booking-form button').first().isDisabled());
await go('candidature-enseignant.html');
step('Candidature enseignant enregistrée',!!tp,(await p.textContent('#confirmation')).trim());
step('Zone d’intervention enregistrée',!!(tp&&tp.location),'location='+(tp&&tp.location));
step('Niveaux enseignés enregistrés',!!(tp&&tp.levels),'levels='+(tp&&tp.levels));
step('Documents de l’enseignant envoyés',!!(tp&&tp.photo_url&&tp.id_doc_path&&tp.diploma_path&&tp.cv_path),[tp&&tp.photo_url,tp&&tp.id_doc_path].join(' | '));
step('Pièce d’identité dans l’espace privé',(d.__storage||[]).some(f=>f.bucket==='teacher-files'&&f.path.startsWith(tp.id+'/idDoc-')));
await go('espace-enseignant.html');step('Espace enseignant : dossier complet',(await p.textContent('#profile')).includes('Dossier complet'));
// 5. Administrateur
await logout();await go('connexion.html');await p.fill('#email','admin@kone.ci');await p.fill('#password','secret1');await p.click('form button');await p.waitForTimeout(800);
step('Connexion admin → administration',p.url().endsWith('espace-admin.html'));
step('Admin : dossier complet et documents',(await p.textContent('#teachers')).includes('Dossier complet')&&(await p.locator('#teachers .doc').count())===3);
await p.locator('#teachers .doc').first().click();await p.waitForTimeout(400);step('Admin : ouverture d’un document privé',JSON.parse(await p.evaluate(()=>localStorage.getItem('__ke_log'))).some(o=>o[0]==='signedUrl'&&o[1]==='teacher-files'));
await p.click('#teachers button:has-text("Valider")');await p.waitForTimeout(500);
d=await db();step('Validation de l’enseignant',d.teacher_profiles[0].approved===true);
const reqId=d.course_requests.find(r=>r.student_name==='Awa Koné').id;
await p.selectOption('#teacher-'+reqId,d.teacher_profiles[0].id);await p.click('#teacher-'+reqId+' ~ button:has-text("Attribuer")');await p.waitForTimeout(600);
d=await db();step('Attribution de l’enseignant',d.course_requests.find(r=>r.id===reqId).teacher_id===d.teacher_profiles[0].id);
step('Pas d’attribution possible sur une demande annulée',(await p.locator('#teacher-'+d.course_requests.find(r=>r.student_name==='Ibrahim Koné').id).count())===0);
step('Zone et niveaux affichés à l’admin',(await p.textContent('#teachers')).includes('Zone : Cocody'));
step('Coordonnées du parent visibles',(await p.locator('#requests .who',{hasText:'Mariam Koné'}).count())>0);
await p.selectOption('#invCourse',String(reqId));await p.fill('#invAmount','40000');await p.click('#invoiceForm button');await p.waitForTimeout(600);
d=await db();step('Création de la facture',(d.invoices||[]).length===1);
// 6. Parent : paiement
await logout();await go('connexion.html');await p.fill('#email','mariam@test.ci');await p.fill('#password','secret1');await p.click('form button');await p.waitForTimeout(800);
await go('paiements.html');await p.selectOption('select[name=method]','wave');await p.fill('input[name=reference]','T_ABC123');await p.click('#list form .btn');await p.waitForTimeout(500);
d=await db();step('Déclaration du paiement par le parent',d.invoices[0].status==='pending'&&d.invoices[0].payment_reference==='T_ABC123');
// 7. Admin confirme
await logout();await go('connexion.html');await p.fill('#email','admin@kone.ci');await p.fill('#password','secret1');await p.click('form button');await p.waitForTimeout(800);
await p.click('text=Confirmer le paiement');await p.waitForTimeout(500);
await p.evaluate(()=>{const db=JSON.parse(localStorage.getItem('__ke_db'));db.invoices[0].paid_at=new Date().toISOString();localStorage.setItem('__ke_db',JSON.stringify(db))});
d=await db();step('Confirmation du paiement par l’admin',d.invoices[0].status==='paid');
await go('espace-admin.html');step('Activité : encaissé ce mois',(await p.textContent('#aMonth')).replace(/\s/g,'').includes('40000'),await p.textContent('#aMonth'));step('Activité : graphiques affichés',(await p.locator('.chart svg').count())===2);
// 8. Enseignant : compte rendu + message
await logout();await go('connexion.html');await p.fill('#email','yao@test.ci');await p.fill('#password','secret1');await p.click('form button');await p.waitForTimeout(800);
step('Espace enseignant : cours attribué visible',(await p.locator('#courses .row',{hasText:'Awa Koné'}).count())===1);
await go('suivi.html?cours='+reqId);await p.selectOption('select[name=understanding]','4');await p.fill('input[name=topics]','Théorème de Pythagore');await p.fill('input[name=homework]','Ex. 4 p.112');await p.click('#reportForm button');await p.waitForTimeout(500);
d=await db();step('Compte rendu de séance',(d.session_reports||[]).length===1);
await go('messagerie.html?cours='+reqId);await p.fill('#body','Bonjour, Awa a bien travaillé.');await p.click('#send');await p.waitForTimeout(500);
d=await db();step('Message de l’enseignant',(d.messages||[]).length===1);
// 9. Parent : suivi, avis, réponse
await logout();await go('connexion.html');await p.fill('#email','mariam@test.ci');await p.fill('#password','secret1');await p.click('form button');await p.waitForTimeout(800);
await go('suivi.html?cours='+reqId);step('Parent voit le compte rendu',(await p.textContent('#reports')).includes('Pythagore'));
await p.click('#stars button:nth-child(5)');await p.fill('#reviewComment','Très bon enseignant');await p.click('#reviewBtn');await p.waitForTimeout(500);
d=await db();step('Avis du parent',(d.reviews||[]).length===1&&d.reviews[0].rating===5);
await go('messagerie.html?cours='+reqId);step('Parent voit le message',(await p.textContent('#thread')).includes('bien travaillé'));
await p.fill('#body','Merci beaucoup !');await p.click('#send');await p.waitForTimeout(500);
d=await db();step('Réponse du parent',(d.messages||[]).length===2);
// 9 bis. Profil public de l’enseignant
await logout();await go('enseignants.html');await p.waitForTimeout(400);const pub=await p.textContent('#teachers-grid');step('Profil public de l’enseignant validé',pub.includes('Yao K.')&&pub.includes('5/5')&&!pub.includes('0500112233'),pub.slice(0,80).replace(/\s+/g,' '));
// 10. Visiteur : formulaire de contact
await logout();await go('contact.html');await p.fill('input[name=name]','Visiteur');await p.fill('input[name=email]','v@test.ci');
const so=await p.$$eval('select[name=subject] option',o=>o.map(x=>x.value||x.textContent).filter(Boolean));await p.selectOption('select[name=subject]',{index:1});await p.fill('textarea[name=message]','Bonjour');
await p.click('#contact-form button[type=submit]');await p.waitForTimeout(500);
d=await db();step('Formulaire de contact',(d.contact_messages||[]).length===1);
console.log('\nErreurs JavaScript :',errs.length?errs:'aucune');console.log('Étapes en échec :',issues.length?issues:'aucune');process.exitCode=issues.length||errs.length?1:0;
await b.close();
