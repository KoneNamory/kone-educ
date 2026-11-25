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
const ctx=await b.newContext({viewport:{width:1366,height:900},serviceWorkers:'block'});
await ctx.route('**/supabase-js@2',r=>r.fulfill({contentType:'text/javascript',body:MOCK}));
await ctx.route(/fonts\.(googleapis|gstatic)\.com/,r=>r.abort());
const p=await ctx.newPage();const errs=[];const issues=[];
p.on('pageerror',e=>errs.push(p.url().split('/').pop()+': '+e.message));
p.on('dialog',d=>d.type()==='prompt'&&d.defaultValue()?d.accept(d.defaultValue()):d.accept());
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
await go('index.html');await p.click('.ke-actions a[href="connexion.html"]');await p.waitForTimeout(300);
step('Accueil : « Se connecter » demande Parent ou Enseignant',await p.locator('dialog.ke-account').isVisible()&&(await p.textContent('dialog.ke-account')).includes('Enseignant'));
await p.click('dialog.ke-account a[href="inscription.html?role=parent"]');await p.waitForTimeout(500);
step('Inscription : compte Parent présélectionné',(await p.inputValue('#role'))==='parent'&&await p.locator('#form').isVisible()&&(await p.textContent('#title')).includes('Parent'));
await go('inscription.html');step('Inscription : la question Parent / Enseignant est posée d’abord',await p.locator('#form').isHidden());await p.click('.role[data-role=parent]');
await p.fill('#fullName','Mariam Koné');await p.fill('#phone','0700112233');await p.fill('#email','mariam@test.ci');await p.fill('#password','secret1');
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
  step('Demande de cours ('+eleve+') : écran de remerciement',(await p.textContent('#confirmation')).includes('succès')&&await p.locator('#booking-success').isVisible()&&(await p.textContent('#booking-success')).includes('Merci')&&(await p.textContent('#booking-success')).includes(eleve)&&await p.locator('#booking-form').isHidden());
}
// 3. Espace parent : demandes visibles + annulation de la 2e
await go('espace-parent.html');
step('Espace parent : 2 demandes en attente',(await p.locator('#list .tag',{hasText:'En attente'}).count())===2);
await p.locator('#list .row',{hasText:'Ibrahim'}).locator('.cancel').click();await p.waitForTimeout(500);
let d=await db();step('Annulation de la 2e demande',d.course_requests.find(r=>r.student_name==='Ibrahim Koné')?.status==='cancelled');
// 3 bis. Un compte Parent ne peut pas déposer de candidature ; la réservation est préremplie sans autocomplétion du nom de l'élève
await go('candidature-enseignant.html');step('Compte Parent bloqué sur la candidature',(await p.textContent('.login-first')).includes('compte Parent')&&await p.locator('#teacher-form button').isDisabled());
await go('offres.html');await p.waitForTimeout(300);step('Offres : page réservée aux enseignants (parent bloqué)',(await p.textContent('#content')).includes('réservée aux enseignants')&&(await p.locator('.o-card').count())===0);
await go('reservation.html');await p.waitForTimeout(300);step('Réservation : bouton « Retour à mon espace » pour le parent',(await p.getAttribute('.back-space','href'))==='espace-parent.html');step('Réservation préremplie avec le compte Parent',(await p.inputValue('input[name=parentName]'))==='Mariam Koné'&&(await p.getAttribute('input[name=studentName]','autocomplete'))==='off');
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
if(!(await p.isChecked('#acceptRI')))await tick('#acceptRI');await p.click('#teacher-form button');await p.waitForTimeout(800);
d=await db();const tp=(d.teacher_profiles||[])[0];
await go('reservation.html');await p.waitForTimeout(300);step('Compte Enseignant bloqué sur la réservation',(await p.textContent('.wrong-account')).includes('compte Enseignant')&&await p.locator('#booking-form button').first().isDisabled());
await go('candidature-enseignant.html');
step('Candidature enseignant enregistrée',!!tp,(await p.textContent('#confirmation')).trim());
step('Zone d’intervention enregistrée',!!(tp&&tp.location),'location='+(tp&&tp.location));
step('Niveaux enseignés enregistrés',!!(tp&&tp.levels),'levels='+(tp&&tp.levels));
step('Documents de l’enseignant envoyés',!!(tp&&tp.photo_url&&tp.id_doc_path&&tp.diploma_path&&tp.cv_path),[tp&&tp.photo_url,tp&&tp.id_doc_path].join(' | '));
step('Pièce d’identité dans l’espace privé',(d.__storage||[]).some(f=>f.bucket==='teacher-files'&&f.path.startsWith(tp.id+'/idDoc-')));
// Dossier incomplet (ancien dossier sans CV ni présentation) : réponses préremplies, éléments manquants signalés
await p.evaluate(()=>{const db=JSON.parse(localStorage.getItem('__ke_db'));delete db.teacher_profiles[0].cv_path;db.teacher_profiles[0].bio='';localStorage.setItem('__ke_db',JSON.stringify(db))});
await go('candidature-enseignant.html');await p.waitForTimeout(400);
const st=await p.textContent('#dossier-status');
step('Dossier incomplet : éléments manquants listés',st.includes('CV')&&st.includes('Présentation')&&!st.includes('Photo de profil'),st.replace(/\s+/g,' ').slice(0,120));
step('Dossier incomplet : réponses préremplies',(await p.inputValue('input[name=location]'))==='Cocody, Bingerville'&&await p.isChecked('input[name=days][value=Mercredi]')&&await p.isChecked('input[name=levels][value=Lycée]')&&!(await p.getAttribute('input[name=photo]','required')!==null)&&(await p.getAttribute('input[name=cv]','required'))!==null);
await p.fill('textarea[name=bio]','Professeur de mathématiques depuis 5 ans.');await p.setInputFiles('input[name=cv]',FILES.doc);
if(await c2.count())await tick('#teacher-form input[type=checkbox]:not([name])');
if(!(await p.isChecked('#acceptRI')))await tick('#acceptRI');await p.click('#teacher-form button');await p.waitForTimeout(800);
d=await db();step('Dossier complété sans tout ressaisir',!!(d.teacher_profiles[0].cv_path&&d.teacher_profiles[0].bio&&d.teacher_profiles[0].photo_url)&&(await p.textContent('#dossier-status')).includes('complet'),(await p.textContent('#confirmation')).trim());
await go('offres.html');await p.waitForTimeout(300);step('Offres : enseignant non validé bloqué',(await p.textContent('#content')).includes('en cours de validation')&&(await p.locator('.o-card').count())===0);
await go('espace-enseignant.html');step('Espace enseignant : dossier complet',(await p.textContent('#profile')).includes('Dossier complet'));
// 5. Administrateur
await logout();await go('connexion.html?espace=equipe');await p.fill('#email',' Admin@Kone.ci ');await p.fill('#password','secret1');await p.click('#form button[type=submit], #form > button');await p.waitForTimeout(800);
step('Connexion admin → administration (e-mail avec espaces et majuscules accepté)',p.url().endsWith('espace-admin.html'));
step('Inscrits : compteurs parents et enseignants',(await p.textContent('#userKpis')).replace(/\s+/g,' ').includes('Parents1')||(await p.textContent('#userKpis')).replace(/\s+/g,'').includes('Parents1'),(await p.textContent('#userKpis')).replace(/\s+/g,' '));
await p.click('#userList .u-row:has-text("Yao Kouassi")');await p.waitForTimeout(300);
step('Inscrits : fiche complète de l’enseignant',await p.locator('#userDialog').isVisible()&&(await p.textContent('#userDetail')).includes('yao@test.ci')&&(await p.textContent('#userDetail')).includes('Dossier complet à 100')&&(await p.textContent('#userDetail')).includes('Cocody, Bingerville'));
await p.evaluate(()=>userDialog.close());
const [dl]=await Promise.all([p.waitForEvent('download'),p.click('#exportBtn')]);const saved=JSON.parse(fs.readFileSync(await dl.path(),'utf8'));
step('Sauvegarde : export complet téléchargé',dl.suggestedFilename().startsWith('kone-educ-sauvegarde-')&&Array.isArray(saved.tables.profiles)&&saved.tables.profiles.length>=3&&Array.isArray(saved.tables.teacher_profiles),dl.suggestedFilename());
step('Journal des actions affiché',(await p.locator('#auditList').count())===1&&!(await p.textContent('#auditList')).includes('Chargement'));
step('Admin : dossier complet et documents',(await p.textContent('#teachers')).includes('Dossier complet')&&(await p.locator('#teachers .doc').count())===3);
await p.locator('#teachers .doc').first().click();await p.waitForTimeout(400);step('Admin : ouverture d’un document privé',JSON.parse(await p.evaluate(()=>localStorage.getItem('__ke_log'))).some(o=>o[0]==='signedUrl'&&o[1]==='teacher-files'));
await p.click('#teachers button:has-text("Valider")');await p.waitForTimeout(500);
d=await db();step('Validation de l’enseignant',d.teacher_profiles[0].approved===true);
const reqId=d.course_requests.find(r=>r.student_name==='Awa Koné').id;
// 5 bis. Offres de cours : l'enseignant validé postule, l'admin choisit sa candidature
await logout();await go('connexion.html?role=teacher');await p.fill('#email','yao@test.ci');await p.fill('#password','secret1');await p.click('#form button[type=submit], #form > button');await p.waitForTimeout(800);
await go('offres.html');await p.waitForTimeout(300);
step('Offres : demande en attente visible, sans le nom de l’élève',(await p.locator('.o-card',{hasText:'Cocody'}).count())===1&&!(await p.textContent('#content')).includes('Awa Koné')&&(await p.textContent('#content')).includes('Votre matière'));
await p.click('.o-card button:has-text("Postuler")');await p.fill('.o-apply textarea','Disponible le mercredi et le samedi.');await p.click('.o-apply button:has-text("Envoyer")');await p.waitForTimeout(500);
d=await db();step('Candidature à une offre',(d.course_applications||[]).length===1&&d.course_applications[0].course_request_id===reqId&&(await p.textContent('#offers')).includes('En cours d’étude'));
await logout();await go('connexion.html?espace=equipe');await p.fill('#email','admin@kone.ci');await p.fill('#password','secret1');await p.click('#form button[type=submit], #form > button');await p.waitForTimeout(800);
step('Admin : candidature visible sur la demande',(await p.locator('#requests .apps',{hasText:'Yao Kouassi'}).count())===1&&(await p.textContent('#requests .apps')).includes('Disponible le mercredi'));
step('Admin : liste des enseignants visible et classée',await p.locator('#teacher-'+reqId).isVisible()&&(await p.textContent('#teacher-'+reqId)).includes('Yao Kouassi')&&(await p.textContent('#teacher-'+reqId)).includes('Recommandé')&&(await p.textContent('#teacher-'+reqId)).includes('Même matière')&&(await p.textContent('#teacher-'+reqId)).includes('A postulé'));
await p.click('#requests .apps button:has-text("Choisir")');await p.waitForTimeout(600);
d=await db();step('Attribution de l’enseignant (candidature choisie)',d.course_requests.find(r=>r.id===reqId).teacher_id===d.teacher_profiles[0].id);
step('Attribution : messages WhatsApp prêts pour le parent et l’enseignant',await p.locator('#waDialog').isVisible()&&(await p.locator('#waList a[href*="wa.me"]').count())===2&&(await p.textContent('#waList')).includes('Mariam Koné'));await p.evaluate(()=>waDialog.close());
step('Facture ponctuelle : cours listés avec le parent',(await p.textContent('#invCourse')).includes('Parent : Mariam Koné'));
step('Pas d’attribution possible sur une demande annulée',(await p.locator('#teacher-'+d.course_requests.find(r=>r.student_name==='Ibrahim Koné').id).count())===0);
step('Zone et niveaux affichés à l’admin',(await p.textContent('#teachers')).includes('Zone : Cocody'));
step('Coordonnées du parent visibles',(await p.locator('#requests .who',{hasText:'Mariam Koné'}).count())>0);
await p.evaluate(()=>{document.getElementById('feesBox').open=true});await p.fill('#fee-'+reqId,'40000');await p.click('#fee-'+reqId+' ~ button');await p.waitForTimeout(500);
d=await db();step('Tarif mensuel du cours enregistré',d.course_requests.find(r=>r.id===reqId).monthly_fee===40000);
await p.click('#genBtn');await p.waitForTimeout(700);
d=await db();step('Factures du mois générées en un clic (échéance le 10)',(d.invoices||[]).length===1&&d.invoices[0].amount===40000&&/-10$/.test(d.invoices[0].due_date||''));
step('Facturation : à encaisser affiché',(await p.textContent('#billKpis')).replace(/\s/g,'').includes('40000'),(await p.textContent('#billKpis')).replace(/\s+/g,' '));
await p.click('#genBtn',{force:true}).catch(()=>{});await p.waitForTimeout(300);d=await db();step('Pas de facture en double',(d.invoices||[]).length===1);
// 6. Parent : paiement
await logout();await go('connexion.html?role=parent');await p.fill('#email','mariam@test.ci');await p.fill('#password','secret1');await p.click('#form button[type=submit], #form > button');await p.waitForTimeout(800);
d=await db();await go('facture.html?id='+d.invoices[0].id);await p.waitForTimeout(400);step('Facture imprimable pour le parent',(await p.textContent('#sheet')).includes('KE-')&&(await p.textContent('#sheet')).includes('Facture')&&(await p.textContent('#sheet')).replace(/\s/g,'').includes('40000FCFA'));
await go('paiements.html');await p.selectOption('select[name=method]','moov_money');await p.fill('input[name=reference]','T_ABC123');await p.click('#list form .btn');await p.waitForTimeout(500);
d=await db();step('Déclaration du paiement par le parent (Moov Money)',d.invoices[0].status==='pending'&&d.invoices[0].payment_method==='moov_money'&&d.invoices[0].payment_reference==='T_ABC123');
// 7. Admin confirme
await logout();await go('connexion.html?espace=equipe');await p.fill('#email','admin@kone.ci');await p.fill('#password','secret1');await p.click('#form button[type=submit], #form > button');await p.waitForTimeout(800);
await p.click('text=Confirmer le paiement');await p.waitForTimeout(500);
{const mid=(await db()).profiles.find(x=>x.full_name==='Mariam Koné').id;
await go('gestion-documents.html?pour='+mid);await p.waitForTimeout(500);
step('Documents : destinataire présélectionné depuis la fiche',await p.locator('#personBox').isVisible()&&(await p.inputValue('#person'))===mid);
await p.fill('#title','Fiche de révision Pythagore');await p.setInputFiles('#file',FILES.doc);await p.click('#publish');await p.waitForTimeout(600);
const dd=(await db()).documents||[];step('Documents : envoi à une personne précise',dd.length===1&&dd[0].audience==='person'&&dd[0].recipient_id===mid&&(await p.textContent('#msg')).includes('Mariam')&&(await p.textContent('#sent')).includes('Pythagore'));
await go('espace-admin.html');await p.waitForTimeout(300);}
await p.evaluate(()=>{const db=JSON.parse(localStorage.getItem('__ke_db'));db.invoices[0].paid_at=new Date().toISOString();localStorage.setItem('__ke_db',JSON.stringify(db))});
d=await db();step('Confirmation du paiement par l’admin',d.invoices[0].status==='paid');
await go('facture.html?id='+d.invoices[0].id);await p.waitForTimeout(400);step('Reçu après paiement',(await p.textContent('#sheet')).includes('Reçu')&&(await p.textContent('#sheet')).includes('PAYÉE'));
await go('espace-admin.html');step('Activité : encaissé ce mois',(await p.textContent('#aMonth')).replace(/\s/g,'').includes('40000'),await p.textContent('#aMonth'));step('Activité : graphiques affichés',(await p.locator('.chart svg').count())===2);
// 7 ter. Tableau de bord
await go('tableau-de-bord.html');await p.waitForTimeout(700);
{const t=await p.textContent('#dash');step('Tableau de bord : chiffres et graphiques affichés',await p.locator('#dash').isVisible()&&(await p.locator('#cSignups svg').count())===1&&(await p.locator('#cRevenue svg').count())===1&&t.includes('cours actifs')&&t.includes('Mathématiques'));}
await p.click('.seg button[data-n="12"]');await p.waitForTimeout(300);step('Tableau de bord : période 12 mois',(await p.locator('#cRequests svg text').count())>=12);
// 7 bis. Versements aux enseignants
await go('versements.html');await p.waitForTimeout(600);
step('Versements : page admin et cours listé',await p.locator('#adminView').isVisible()&&(await p.locator('#rate-'+reqId).count())===1);
await p.fill('#rate-'+reqId,'30000');await p.click('#rates .rate-row:has(#rate-'+reqId+') button');await p.waitForTimeout(500);
d=await db();step('Versements : rémunération enregistrée',(d.teacher_rates||[]).some(x=>x.course_request_id===reqId&&x.monthly_amount===30000));
await p.click('#genBtn');await p.waitForTimeout(500);
d=await db();step('Versements : versement du mois généré',(d.teacher_payouts||[]).length===1&&d.teacher_payouts[0].amount===30000&&d.teacher_payouts[0].status==='due');
{const pid=d.teacher_payouts[0].id;await p.selectOption('#met-'+pid,'wave');await p.fill('#ref-'+pid,'WV123');await p.click('#payouts .p-row button:has-text("Marquer versé")');await p.waitForTimeout(500);}
d=await db();step('Versements : marqué comme versé',d.teacher_payouts[0].status==='paid'&&d.teacher_payouts[0].payment_method==='wave'&&d.teacher_payouts[0].payment_reference==='WV123');
// 8. Enseignant : compte rendu + message
await logout();await go('connexion.html?role=teacher');await p.fill('#email','yao@test.ci');await p.fill('#password','secret1');await p.click('#form button[type=submit], #form > button');await p.waitForTimeout(800);
await go('versements.html');await p.waitForTimeout(600);{const tv=await p.textContent('#teacherView');step('Mes gains : versement visible côté enseignant',await p.locator('#teacherView').isVisible()&&tv.includes('30')&&tv.includes('Wave')&&await p.locator('#adminView').isHidden());}
await go('ressources.html');await p.waitForTimeout(500);step('Cloche : notification non lue visible',(await p.locator('.ke-bell span:not([hidden])').count())===1,await p.textContent('.ke-bell'));
await p.click('.ke-bell');await p.waitForTimeout(200);step('Cloche : panneau avec la notification',(await p.textContent('.ke-panel')).includes('Nouveau cours attribué'));
await p.click('.ke-n:has-text("Nouveau cours attribué")');await p.waitForTimeout(800);d=await db();
step('Notification ouverte : marquée lue et page du cours',p.url().endsWith('espace-enseignant.html')&&d.notifications.filter(n=>n.title==='Nouveau cours attribué').every(n=>n.is_read));
step('Espace enseignant : cours attribué visible',(await p.locator('#courses .row',{hasText:'Awa Koné'}).count())===1);
// Planning : l'enseignant planifie des séances et signale une absence
await go('planning.html');await p.waitForTimeout(400);step('Planning : formulaire de planification (enseignant)',await p.locator('#planCard').isVisible());
await p.evaluate(()=>{planBox.open=true});await p.check('#plDays input[value="3"]');await p.check('#plDays input[value="6"]');await p.selectOption('#plWeeks','2');await p.selectOption('#plCourse',String(reqId));
await p.click('#planForm button');await p.waitForTimeout(600);
d=await db();step('Planning : séances créées (2 jours × 2 semaines)',(d.sessions||[]).length>=3&&(d.sessions||[]).every(x=>x.course_request_id===reqId),String((d.sessions||[]).length));
step('Planning : séances affichées',(await p.locator('.pl-s').count())===d.sessions.length);
await p.locator('.pl-s').first().locator('button:has-text("Absent")').click();await p.waitForTimeout(500);
d=await db();step('Planning : absence enregistrée',d.sessions.filter(x=>x.status==='absent').length===1);
await go('espace-enseignant.html');await p.waitForTimeout(500);step('Espace enseignant : prochains cours affichés',(await p.locator('#nextList .d-note').count())>=1);
await go('suivi.html?cours='+reqId);await p.selectOption('select[name=understanding]','4');await p.fill('input[name=topics]','Théorème de Pythagore');await p.fill('input[name=homework]','Ex. 4 p.112');await p.click('#reportForm button');await p.waitForTimeout(500);
d=await db();step('Compte rendu de séance',(d.session_reports||[]).length===1);
await p.evaluate(([cid])=>{const d=JSON.parse(localStorage.getItem('__ke_db'));const c=d.course_requests.find(x=>x.id===cid);d.first_lesson_feedback=[{course_request_id:cid,parent_id:c.parent_id,teacher_id:c.teacher_id,asked_at:new Date().toISOString(),answer:null,answered_at:null,wants_change:false}];localStorage.setItem('__ke_db',JSON.stringify(d))},[reqId]);
await go('bilan.html?cours='+reqId);await p.waitForTimeout(500);step('Bilan : courbe et notions du mois',await p.locator('#chart svg').count()===1&&(await p.textContent('#sheet')).includes('Pythagore'));
await p.fill('textarea[name=appreciation]','Awa progresse bien ce mois-ci.');await p.fill('textarea[name=strengths]','Calcul littéral');await p.click('#apprForm button');await p.waitForTimeout(600);
d=await db();step('Bilan : appréciation publiée par l’enseignant',(d.monthly_assessments||[]).length===1&&(await p.textContent('#apprBox')).includes('progresse bien'));
await go('messagerie.html?cours='+reqId);await p.fill('#body','Bonjour, Awa a bien travaillé.');await p.click('#send');await p.waitForTimeout(500);
d=await db();step('Message de l’enseignant',(d.messages||[]).length===1);
// 9. Parent : suivi, avis, réponse
await logout();await go('connexion.html?role=parent');await p.fill('#email','mariam@test.ci');await p.fill('#password','secret1');await p.click('#form button[type=submit], #form > button');await p.waitForTimeout(800);
await go('suivi.html?cours='+reqId);step('Parent voit le compte rendu',(await p.textContent('#reports')).includes('Pythagore'));
await go('espace-parent.html');await p.waitForTimeout(600);step('Espace parent : bandeau « premier cours » affiché',(await p.locator('#fbBanner .fb-banner').count())===1);
await p.click('#fbBanner .fb-banner');await p.waitForTimeout(700);
await p.click('.fb-choice.bad');step('Avis premier cours : 👎 propose le changement d’enseignant',await p.locator('#changeRow').isVisible());
await p.fill('#comment','Retard au premier cours');await p.check('#wantsChange');await p.click('#sendBtn');await p.waitForTimeout(500);
d=await db();step('Avis premier cours : réponse enregistrée',d.first_lesson_feedback[0].answer==='bad'&&d.first_lesson_feedback[0].wants_change===true&&(await p.textContent('#card')).includes('Merci'));
await go('espace-parent.html');await p.waitForTimeout(500);step('Espace parent : bandeau retiré après réponse',(await p.locator('#fbBanner .fb-banner').count())===0);
await go('suivi.html?cours='+reqId);await p.waitForTimeout(400);
await p.click('#stars button:nth-child(5)');await p.fill('#reviewComment','Très bon enseignant');await p.click('#reviewBtn');await p.waitForTimeout(500);
d=await db();step('Avis du parent',(d.reviews||[]).length===1&&d.reviews[0].rating===5);
await go('bilan.html?cours='+reqId);await p.waitForTimeout(500);const bil=await p.textContent('#sheet');step('Bilan parent : appréciation visible, sans formulaire',bil.includes('progresse bien')&&bil.includes('Calcul littéral')&&await p.locator('#apprForm').count()===0);
await go('planning.html');await p.waitForTimeout(400);step('Planning parent : séances visibles, sans planification',(await p.locator('.pl-s').count())>=2&&await p.locator('#planCard').isHidden());
await p.locator('.pl-s button:has-text("Demander un report")').first().click();await p.waitForTimeout(500);
d=await db();step('Planning parent : demande de report envoyée',d.sessions.some(x=>(x.change_request||'').startsWith('Demande de report')));
await go('messagerie.html?cours='+reqId);step('Parent voit le message',(await p.textContent('#thread')).includes('bien travaillé'));
await p.fill('#body','Merci beaucoup !');await p.click('#send');await p.waitForTimeout(500);
d=await db();step('Réponse du parent',(d.messages||[]).length===2);
// 9 bis. Profil public de l’enseignant
await logout();await go('enseignants.html');await p.waitForTimeout(400);const pub=await p.textContent('#teachers-grid');step('Profil public de l’enseignant validé',pub.includes('Yao K.')&&pub.includes('5/5')&&!pub.includes('0500112233'),pub.slice(0,80).replace(/\s+/g,' '));
await p.locator('#teachers-grid .teacher',{hasText:'Yao K.'}).locator('a.book',{hasText:'Voir le profil'}).click();await p.waitForTimeout(800);
const fiche=await p.textContent('#page');step('Fiche publique : profil, note et avis vérifié publié',p.url().includes('enseignant.html?id=')&&fiche.includes('Yao K.')&&fiche.includes('Très bon enseignant')&&fiche.includes('Avis vérifié')&&!fiche.includes('0500112233')&&!fiche.includes('Kouassi'));
await go('connexion.html?role=parent');await p.fill('#email','mariam@test.ci');await p.fill('#password','secret1');await p.click('#form button[type=submit], #form > button');await p.waitForTimeout(800);
await go('enseignants.html');await p.locator('#teachers-grid .teacher',{hasText:'Yao K.'}).locator('a.book',{hasText:'Demander cet enseignant'}).click();await p.waitForTimeout(900);
step('Réservation : enseignant souhaité affiché',(await p.textContent('#chosen-teacher')).includes('Yao K.'));
await p.fill('input[name=studentName]','Fatou Koné');{const lv=await p.$$eval('select[name=level] option',o=>o.map(x=>x.value).filter(Boolean));await p.selectOption('select[name=level]',lv[2]);}
await p.selectOption('#commune','Cocody');await p.waitForTimeout(100);{const qs=await p.$$eval('#quartier option',o=>o.map(x=>x.value).filter(Boolean));await p.selectOption('#quartier',qs[0]);}
await tick('input[name=format][value="À domicile"]');await tick('input[name=days][value=Samedi]');
{const consent=p.locator('#booking-form input[type=checkbox]:not([name])');if(await consent.count())await tick('#booking-form input[type=checkbox]:not([name])');}
await p.click('#booking-form button[type=submit], #booking-form button');await p.waitForTimeout(700);
d=await db();{const last=d.course_requests[d.course_requests.length-1];const yao=d.profiles.find(x=>x.full_name&&x.full_name.startsWith('Yao'));step('Demande envoyée avec l’enseignant souhaité',last.student_name==='Fatou Koné'&&yao&&last.preferred_teacher_id===yao.id&&(await p.textContent('#booking-success')).includes('Yao K.'));}
// 9 ter. Suppression de compte (exigence Google Play)
await go('connexion.html?role=parent');await p.fill('#email','mariam@test.ci');await p.fill('#password','secret1');await p.click('#form button[type=submit], #form > button');await p.waitForTimeout(800);
await go('espace-parent.html');step('Espace parent : lien « Supprimer mon compte »',(await p.locator('a[href="suppression-compte.html"]').count())===1);
await go('suppression-compte.html');await p.waitForTimeout(500);step('Suppression : bouton désactivé tant que non confirmé',await p.locator('#scForm').isVisible()&&await p.locator('#scBtn').isDisabled());
await p.check('#scConfirm');await p.fill('#scReason','Test');await p.click('#scBtn');await p.waitForTimeout(500);
d=await db();step('Suppression : demande enregistrée',!!d.profiles.find(x=>x.full_name==='Mariam Koné').deletion_requested_at&&(await p.textContent('#scMsg')).includes('Demande envoyée'));
await logout();await go('suppression-compte.html');await p.waitForTimeout(400);step('Suppression : marche à suivre visible sans connexion',await p.locator('#scLogin').isVisible()&&await p.locator('#scForm').isHidden());
await logout();await go('connexion.html');step('Connexion : aucun accès administration visible',!(await p.content()).includes('administration')&&(await p.locator('#adminLink').count())===0);
// 9 quater. Pages locales (référencement Google)
await logout();await go('cours-particuliers-a-domicile-cocody.html');await p.waitForTimeout(600);
step('Page locale Cocody : titre, quartiers et FAQ',(await p.textContent('h1')).includes('Cocody')&&(await p.textContent('main')).includes('Riviera')&&(await p.locator('.faq details').count())>=5&&(await p.locator('script[type="application/ld+json"]').count())===1);
await p.click('.l-cta a.l-btn');await p.waitForTimeout(600);step('Page locale → réservation : commune présélectionnée',(await p.inputValue('#commune'))==='Cocody'&&!(await p.locator('#quartier').isDisabled()));
await p.selectOption('#commune','Autre commune (à préciser)');await p.fill('#commune-autre','Grand-Bassam');await p.fill('#quartier-autre','Mockeyville');
step('Réservation : autre commune saisie et marquée à vérifier',(await p.locator('#quartier').isHidden())&&(await p.evaluate(()=>getAbidjanLocation('commune','quartier').text))==='Grand-Bassam · Mockeyville (à vérifier)');
await p.selectOption('#commune','Cocody');await p.selectOption('#quartier','Autre quartier');await p.fill('#quartier-autre','Palmeraie');
await p.selectOption('#commune','Grand-Bassam');step('Réservation : commune des environs (Grand-Bassam) avec ses quartiers',(await p.$$eval('#quartier option',o=>o.map(x=>x.value))).includes('Mockeyville'));
await p.selectOption('#commune','Cocody');await p.selectOption('#quartier','Autre quartier');await p.fill('#quartier-autre','Palmeraie');
step('Réservation : autre quartier précisé',(await p.locator('#commune-autre').isHidden())&&(await p.evaluate(()=>getAbidjanLocation('commune','quartier').text))==='Cocody · Palmeraie');
await go('cours-de-mathematiques-a-domicile-abidjan.html');await p.waitForTimeout(800);step('Page matière : enseignants de mathématiques affichés',(await p.locator('#teachers .t').count())>=1);
// 9 quinquies. Boutique : vendeur, validation, commande d'un parent, livraison, avis
const loginAs=async(role,email)=>{await logout();await go(role==='admin'?'connexion.html?espace=equipe':'connexion.html?role='+role);await p.fill('#email',email);await p.fill('#password','secret1');await p.click('#form button[type=submit], #form > button');await p.waitForTimeout(900)};
await logout();await go('index.html');await p.click('.ke-actions a[href="connexion.html"]');await p.waitForTimeout(300);
step('Accueil : la fenêtre de connexion propose aussi « Vendeur »',(await p.textContent('dialog.ke-account')).includes('Vendeur'));
await go('devenir-vendeur.html');step('Page « Devenir vendeur » : avantages, étapes et FAQ',(await p.locator('.dv-card').count())===6&&(await p.locator('.dv-faq details').count())>=6&&(await p.locator('a[href="inscription.html?role=seller"]').count())>=1);
await go('inscription.html?role=seller');step('Inscription : carte Vendeur présélectionnée',(await p.textContent('#title'))==='Compte Vendeur');
await p.fill('#fullName','Awa Traoré');await p.fill('#phone','0701010101');await p.fill('#email','awa@test.ci');await p.fill('#password','secret1');await p.click('#form button');await p.waitForTimeout(1200);
d=await db();step('Inscription vendeur → espace vendeur',p.url().includes('espace-vendeur.html')&&d.profiles.some(x=>x.full_name==='Awa Traoré'&&x.role==='seller'));
step('Espace vendeur : formulaire d’ouverture de boutique',await p.locator('#sf').isVisible()&&(await p.locator('.v-zone').count())>=15);
await p.fill('#sName','Librairie Awa');await p.fill('#sAddr','Face à la pharmacie');await p.selectOption('#sCommune','Cocody');await p.selectOption('#sQuartier','Angré');
await p.fill('#sAll','1000');await p.click('button:has-text("Appliquer à toutes les communes")');
await tick('#sMomo');await p.fill('#sWave','0701010101');await tick('#sTerms');await p.click('#sBtn');await p.waitForTimeout(1200);
d=await db();const shopRow=(d.shops||[])[0]||{};
step('Boutique créée en attente, frais de livraison enregistrés',shopRow.name==='Librairie Awa'&&shopRow.status==='pending'&&shopRow.delivery_fees&&shopRow.delivery_fees.Yopougon===1000&&shopRow.pay_momo===true&&shopRow.commune==='Cocody');
step('Après ouverture : formulaire du premier article ouvert',await p.locator('#pf').isVisible()&&(await p.textContent('#statusBox')).includes('vérification'));
await p.fill('#pName','Annales BEPC Maths');await p.selectOption('#pCat','annales');await p.selectOption('#pLevel','3e');await p.fill('#pPrice','3000');await p.fill('#pStock','2');await p.click('#pBtn');await p.waitForTimeout(800);
await p.click('button:has-text("+ Ajouter un article")');await p.waitForTimeout(300);await p.fill('#pName','Cahier 200 pages');await p.fill('#pPrice','500');await p.click('#pBtn');await p.waitForTimeout(800);
d=await db();step('Vendeur : 2 articles ajoutés (stock limité et illimité)',(d.products||[]).length===2&&d.products.find(x=>x.name==='Cahier 200 pages').stock===null&&d.products.find(x=>x.name.startsWith('Annales')).stock===2);
await logout();await go('boutique.html');await p.waitForTimeout(800);step('Boutique publique : boutique non validée invisible',(await p.locator('.bq-card').count())===0);
await loginAs('admin','admin@kone.ci');await go('espace-admin.html#shops');await p.waitForTimeout(1200);
step('Admin : boutique à valider listée',(await p.textContent('#shopList')).includes('Librairie Awa')&&(await p.textContent('#shopKpis')).includes('1 à valider'));
await p.click('#shopList button:has-text("Valider")');await p.waitForTimeout(800);d=await db();step('Admin : boutique validée',d.shops[0].status==='approved');
await loginAs('parent','mariam@test.ci');await go('boutique.html');await p.waitForTimeout(900);
step('Boutique : articles et boutique visibles',(await p.locator('.bq-card').count())===2&&(await p.locator('.bq-shop').count())===1);
await p.fill('#q','annales');await p.waitForTimeout(200);step('Boutique : recherche',(await p.locator('.bq-card').count())===1);await p.fill('#q','');await p.waitForTimeout(200);
await p.selectOption('#commune','Yopougon');await p.waitForTimeout(200);step('Boutique : frais de livraison selon la commune',(await p.textContent('.bq-shop')).includes('1 000 FCFA à Yopougon'));
const card=n=>p.locator('.bq-card',{hasText:n});
await card('Annales').locator('.bq-add').click();await card('Annales').locator('button[aria-label="Ajouter un"]').click();await card('Annales').locator('button[aria-label="Ajouter un"]').click();
await card('Cahier').locator('.bq-add').click();
step('Panier : stock respecté (2 annales max) et barre du panier',(await card('Annales').locator('.bq-step span').textContent())==='2'&&(await p.textContent('#barN'))==='3 articles'&&(await p.textContent('#barT')).includes('6 500'));
await p.click('#bar');await p.waitForTimeout(300);await p.click('#dlgBody button:has-text("Commander chez")');await p.waitForTimeout(500);
step('Commande : nom et téléphone préremplis, commune reprise',(await p.inputValue('#ckName'))==='Mariam Koné'&&(await p.inputValue('#ckCommune'))==='Yopougon');
await p.selectOption('#ckQuartier','Niangon');await p.fill('#ckAddr','Rue 12, portail bleu');
step('Commande : total avec livraison',(await p.textContent('#ckSum')).includes('7 500'));
await p.click('#ckBtn');await p.waitForTimeout(1000);d=await db();const ord=(d.orders||[])[0]||{};
step('Commande envoyée : prix et frais calculés, stock décrémenté',ord.total===7500&&ord.delivery_fee===1000&&ord.status==='new'&&d.products.find(x=>x.name.startsWith('Annales')).stock===0&&(await p.textContent('#dlgBody')).includes(ord.ref));
step('Commande : panier vidé et lien WhatsApp vers le vendeur',(await p.locator('#bar').isHidden())&&(await p.locator('#dlgBody a[href*="wa.me/2250701010101"]').count())===1);
await go('mes-commandes.html');await p.waitForTimeout(900);step('Mes commandes : commande suivie avec ses étapes',(await p.textContent('#list')).includes('Librairie Awa')&&(await p.locator('.c-steps .on').count())===1);
await loginAs('seller','awa@test.ci');await go('espace-vendeur.html');await p.waitForTimeout(1200);
step('Vendeur : nouvelle commande à traiter',(await p.locator('.v-order.new').count())===1&&(await p.textContent('.v-order')).includes('Rue 12'));
await p.click('.v-order button:has-text("Accepter")');await p.waitForTimeout(900);
await p.click('.v-chips button:has-text("En cours")');await p.waitForTimeout(200);await p.click('.v-order button:has-text("Partie en livraison")');await p.waitForTimeout(800);
d=await db();step('Vendeur : commande acceptée puis en livraison',d.orders[0].status==='delivering');
await loginAs('parent','mariam@test.ci');await go('mes-commandes.html');await p.waitForTimeout(900);
await p.click('button:has-text("J’ai reçu ma commande")');await p.waitForTimeout(900);
await p.click('#st'+ord.id+' button[aria-label="5 sur 5"]');await p.fill('#rv'+ord.id,'Livraison rapide !');await p.click('button:has-text("Envoyer mon avis")');await p.waitForTimeout(900);
d=await db();step('Parent : réception confirmée et avis 5 étoiles',d.orders[0].status==='delivered'&&d.orders[0].payment_status==='paid'&&d.orders[0].rating===5);
await go('boutique.html?shop='+d.shops[0].id);await p.waitForTimeout(900);step('Page boutique : note et avis affichés',(await p.textContent('.bq-shophead')).includes('5.0')&&(await p.textContent('#reviews')).includes('Livraison rapide'));
await card('Cahier').locator('.bq-add').click();await p.click('#bar');await p.waitForTimeout(300);await p.click('#dlgBody button:has-text("Commander chez")');await p.waitForTimeout(400);
await tick('#dlgBody input[name=mode][value=pickup]');await tick('#dlgBody input[name=pay][value=momo]');await p.click('#ckBtn');await p.waitForTimeout(1000);
step('Commande mobile money : numéros Wave affichés',(await p.textContent('#momoBox')).includes('0701010101'));
await go('mes-commandes.html');await p.waitForTimeout(900);const o2=(await db()).orders[1];await p.fill('#ref'+o2.id,'WAVE-998877');await p.click('#m'+o2.id+' button');await p.waitForTimeout(800);
await loginAs('seller','awa@test.ci');await go('espace-vendeur.html');await p.waitForTimeout(1200);
step('Vendeur : paiement signalé visible',(await p.textContent('.v-order.new')).includes('WAVE-998877'));
await p.click('.v-order.new button:has-text("Refuser")');await p.waitForTimeout(900);d=await db();
step('Vendeur : refus avec raison, client prévenu',d.orders[1].status==='refused'&&!!d.orders[1].cancel_reason);
await p.click('.v-tabs button:has-text("Statistiques")');await p.waitForTimeout(300);step('Vendeur : statistiques (ventes, meilleurs articles, avis)',(await p.textContent('#panel')).includes('7 500')||(await p.textContent('#panel')).includes('6 500'));
await p.click('.v-tabs button:has-text("Ma boutique")');await p.waitForTimeout(300);step('Vendeur : lien de partage de la boutique',(await p.inputValue('.v-share input')).includes('boutique.html?shop='));
// 9 sexies. Préparations, écoles qui recrutent, offres publiques, journal de la boutique
await loginAs('parent','mariam@test.ci');await go('reservation.html?preparation='+encodeURIComponent('ENSEA – ISE Maths'));
step('Réservation : préparation ENSEA présélectionnée (9 préparations proposées)',(await p.inputValue('#preparation'))==='ENSEA – ISE Maths'&&(await p.locator('#preparation option').count())===10);
await go('services.html');step('Services : section examens et concours (CEPE → INPHB)',(await p.locator('#preparations a[href^="reservation.html?preparation="]').count())===9);
await logout();await go('ecoles.html');
await p.fill('#eSchool','Lycée Les Pionniers');await p.selectOption('#eType','Collège / Lycée');await p.selectOption('#eCommune','Bingerville');await p.selectOption('#eQuartier',{index:1});
await p.fill('#eContact','M. Bamba');await p.fill('#ePhone','0707070707');await tick('#eSubjects input[value="Mathématiques"]');await p.fill('#eLevels','Terminale');await p.selectOption('#ePrep','BAC');await p.selectOption('#eContract','Vacation');await p.fill('#eSalary','5 000 F / heure');
await p.click('#eBtn');await p.waitForTimeout(800);d=await db();
step('École : demande déposée sans compte',(d.school_requests||[]).length===1&&d.school_requests[0].subjects==='Mathématiques'&&d.school_requests[0].preparation==='BAC'&&await p.locator('#ecOk').isVisible());
await go('offres-enseignants.html');await p.waitForTimeout(800);
step('Offres publiques : offre d’école visible, partage WhatsApp et données Google',(await p.locator('.of-card .of-kind.ecole').count())===1&&(await p.locator('.of-card a.wa').count())>=1&&(await p.locator('script[type="application/ld+json"]').evaluateAll(x=>x.some(e=>e.textContent.includes('JobPosting')))));
await loginAs('teacher','yao@test.ci');await go('candidature-enseignant.html');await p.waitForTimeout(600);step('Candidature : 9 préparations à cocher',(await p.locator('#prepChecks input').count())===9);
await go('offres.html#ecoles');await p.waitForTimeout(900);
const schoolCards=await p.locator('.o-card:has-text("Mathématiques")').count();
step('Enseignant : onglet « Offres d’écoles » sans coordonnées de l’école',schoolCards>=1&&!(await p.textContent('#offers')).includes('0707070707'));
await p.click('button:has-text("Je suis intéressé(e)")');await p.waitForTimeout(700);d=await db();step('Enseignant : intérêt envoyé',(d.school_interests||[]).length===1);
await loginAs('admin','admin@kone.ci');await go('espace-admin.html#schools');await p.waitForTimeout(1200);
step('Admin : demande d’école avec l’enseignant intéressé en tête',(await p.textContent('#schoolList')).includes('Lycée Les Pionniers')&&(await p.locator('#schoolList select option').nth(1).textContent()).includes('🙋'));
await p.selectOption('#schoolList select',{index:1});await p.click('#schoolList button:has-text("Mettre en relation")');await p.waitForTimeout(800);d=await db();
step('Admin : mise en relation, l’enseignant reçoit le contact',d.school_requests[0].status==='matched'&&(d.notifications||[]).some(n=>n.title==='Mise en relation avec une école'&&n.body.includes('0707070707')));
step('Admin : journal boutique (commandes, entrées/sorties)',(await p.textContent('#logList')).includes('#R10')&&(await p.textContent('#logKpis')).includes('livrée'));
await p.click('#shoplog button:has-text("Entrées / sorties")');await p.waitForTimeout(200);step('Admin : mouvements de stock (ventes)',(await p.textContent('#logList')).includes('Sortie (vente)'));
await loginAs('seller','awa@test.ci');await go('espace-vendeur.html');await p.waitForTimeout(1000);await p.click('.v-tabs button:has-text("Mes articles")');await p.waitForTimeout(200);await p.click('button:has-text("Entrées / sorties")');await p.waitForTimeout(600);
step('Vendeur : historique des entrées et sorties',(await p.textContent('#dlgBody')).includes('Vente'));
await logout();await go('reglement-interieur.html');step('Règlement intérieur : 20 articles, numéro de dépôt, taux des frais jamais affiché',(await p.locator('.art').count())===20&&(await p.textContent('main')).includes('01 61 70 13 61')&&!/18 ?%|82 ?%/.test(await p.content()));
await go('candidature-enseignant.html');step('Candidature : taux des frais de service non affiché',!/18 ?%|82 ?%/.test(await p.textContent('body')));
step('Pied de page : lien vers le règlement intérieur',(await p.locator('footer a[href="reglement-interieur.html"]').count())===1);
// 9 septies. Ordre et traçabilité : règlement vendeur, litige, signalement, cohérence, relevé
d=await db();step('Vendeur : acceptation du règlement enregistrée à l’ouverture',!!d.shops[0].terms_accepted_at);
await loginAs('parent','mariam@test.ci');await go('mes-commandes.html');await p.waitForTimeout(900);
const firstOrd=(await db()).orders[0];
await p.locator('.c-order').filter({hasText:firstOrd.ref}).locator('button:has-text("Signaler un problème")').click();await p.waitForTimeout(900);
d=await db();step('Client : problème signalé sur une commande livrée',(d.order_disputes||[]).length===1&&(await p.textContent('#list')).includes('Problème signalé'));
await go('boutique.html?shop='+d.shops[0].id);await p.waitForTimeout(800);await p.locator('.bq-card .img').first().click();await p.waitForTimeout(300);
await p.evaluate(()=>{window.prompt=()=>'Prix abusif'});await p.click('button:has-text("Signaler cet article")');await p.waitForTimeout(600);
d=await db();step('Client : article signalé',(d.product_reports||[]).length===1);
await loginAs('seller','awa@test.ci');await go('espace-vendeur.html');await p.waitForTimeout(1000);await p.click('.v-chips button:has-text("Toutes")');await p.waitForTimeout(200);
step('Vendeur : litige visible sur la commande',(await p.textContent('#panel')).includes('Le client signale un problème'));
await p.click('.v-tabs button:has-text("Statistiques")');await p.waitForTimeout(300);step('Vendeur : relevé mensuel disponible',(await p.locator('#relMois').count())===1&&(await p.locator('button:has-text("Imprimer le relevé")').count())===1);
await loginAs('admin','admin@kone.ci');await go('espace-admin.html#shoplog');await p.waitForTimeout(1300);
step('Admin : indicateurs de sérieux des boutiques',(await p.textContent('#shopList')).includes('délai moyen de réponse')&&(await p.textContent('#shopList')).includes('règlement accepté'));
await p.click('#shoplog button:has-text("Litiges")');await p.waitForTimeout(200);await p.click('#logList button:has-text("Traiter le litige")');await p.waitForTimeout(900);
d=await db();step('Admin : litige traité',d.order_disputes[0].status==='resolved'&&!!d.order_disputes[0].resolution);
await p.click('#shoplog button:has-text("Articles signalés")');await p.waitForTimeout(200);await p.click('#logList button:has-text("Masquer l’article")');await p.waitForTimeout(900);
d=await db();step('Admin : article signalé masqué',d.products.find(x=>x.id===d.product_reports[0].product_id).active===false&&d.product_reports[0].handled===true);
await p.click('#shoplog button:has-text("Contrôle de cohérence")');await p.waitForTimeout(700);step('Admin : contrôle de cohérence',(await p.textContent('#cohBox')).includes('Tout est cohérent'));
// 9 octies. Offres KONE.EDUC : publiées par l'admin, visibles par tous, candidatures des enseignants
await loginAs('admin','admin@kone.ci');await go('espace-admin.html#joboffers');await p.waitForTimeout(1200);
await p.click('#joForm summary');await p.fill('#joTitle','Enseignant(e) en 3e à Bingerville');await p.fill('#joLevel','3e');await p.fill('#joSubjects','Maths, Physique-Chimie, Français, Anglais');await p.selectOption('#joCommune','Bingerville');await p.fill('#joRem','40 000 F / mois');await p.click('#joBtn');await p.waitForTimeout(900);
d=await db();step('Admin : offre KONE.EDUC publiée',(d.job_offers||[]).length===1&&d.job_offers[0].status==='open'&&(await p.textContent('#joList')).includes('Bingerville'));
await logout();await go('offres-enseignants.html');await p.waitForTimeout(900);
step('Visiteur : offre KONE.EDUC visible avec bouton Postuler',(await p.locator('#koneList .of-kone').count())===1&&(await p.textContent('#koneList')).includes('40 000 F / mois')&&(await p.locator('#koneList button:has-text("Postuler")').count())===1);
await loginAs('teacher','yao@test.ci');await go('offres-enseignants.html');await p.waitForTimeout(900);
await p.evaluate(()=>{window.prompt=()=>'Professeur certifié, disponible le mercredi'});await p.click('#koneList button:has-text("Postuler")');await p.waitForTimeout(900);
d=await db();step('Enseignant : candidature envoyée',(d.job_applications||[]).length===1&&(await p.textContent('#koneList')).includes('Candidature envoyée'));
await go('espace-enseignant.html');await p.waitForTimeout(900);step('Enseignant : lien « Offres KONE.EDUC » dans son menu',(await p.locator('.ke-app-nav a[href="offres-enseignants.html"]').count())===1);
await loginAs('admin','admin@kone.ci');await go('espace-admin.html#joboffers');await p.waitForTimeout(1200);
step('Admin : candidat visible (dossier, message)',(await p.textContent('#joList')).includes('Yao Kouassi')&&(await p.textContent('#joList')).includes('disponible le mercredi'));
await p.click('#joList button:has-text("Retenir")');await p.waitForTimeout(900);d=await db();
step('Admin : candidat retenu, offre pourvue',d.job_offers[0].status==='filled'&&d.job_applications[0].status==='accepted');
await loginAs('teacher','yao@test.ci');await go('offres-enseignants.html');await p.waitForTimeout(900);step('Enseignant : voit qu’il est retenu',(await p.textContent('#koneList')).includes('retenu'));
await logout();await go('index.html');step('Accueil : section « Examens et concours » et lien Concours dans le menu',(await p.locator('#concours a[href^="reservation.html?preparation="]').count())===9&&(await p.locator('.ke-links a[href="preparation-concours.html"]').count())===1);
await go('preparation-concours.html');step('Page Concours : CEPE, BEPC, BAC, ENSEA, INPHB avec réservation directe',(await p.locator('.pc-card').count())===9&&(await p.textContent('main')).includes('ISE Économie')&&(await p.textContent('main')).includes('A2GP'));
await p.click('.pc-card:has-text("INPHB – ITA") a');await p.waitForTimeout(600);step('Concours → réservation avec la préparation choisie',(await p.inputValue('#preparation'))==='INPHB – ITA');
// 9 nonies. Reçus numérotés, paiements 4 opérateurs, À propos sans fondateurs
await logout();await go('a-propos.html');step('À propos : mission élargie, fondateurs retirés du site',(await p.textContent('main')).includes('prépare aux examens et aux concours')&&!(await p.textContent('main')).includes('Namory')&&!(await p.content()).includes('fondateurs/kone'));
await go('index.html');step('Google : fondateurs toujours dans les données structurées',(await p.locator('script[type="application/ld+json"]').first().textContent()).includes('Kone Namory'));
await loginAs('parent','mariam@test.ci');await go('paiements.html');await p.waitForTimeout(1200);
step('Parent : « Mes reçus » avec le reçu de la mensualité confirmée',(await p.textContent('#mesRecus')).includes('R-2026-')&&(await p.textContent('#mesRecus')).includes('Mensualité'));
await p.locator('#mesRecus a.rc-item').filter({hasText:'Mensualité'}).first().click();await p.waitForTimeout(1000);
step('Reçu imprimable : numéro, montant en lettres, moyen de paiement',(await p.textContent('#out')).includes('Reçu de paiement')&&(await p.textContent('#out')).includes('francs CFA')&&(await p.locator('button:has-text("Imprimer")').count())===1);
await go('mes-commandes.html');await p.waitForTimeout(1200);step('Acheteur : reçus des commandes payées',(await p.textContent('#mesRecus')).includes('Commande'));
await loginAs('seller','awa@test.ci');await go('espace-vendeur.html');await p.waitForTimeout(1000);await p.click('.v-tabs button:has-text("Statistiques")');await p.waitForTimeout(800);
step('Vendeur : reçus de ses ventes',(await p.textContent('#mesRecus')).includes('Reçus de mes ventes')&&(await p.textContent('#mesRecus')).includes('R-2026-'));
await loginAs('admin','admin@kone.ci');await go('espace-admin.html#receipts');await p.waitForTimeout(1500);
step('Admin : tous les reçus, recherche et export',(await p.locator('#allRecus a.rc-item').count())>=2&&(await p.locator('#allRecus .rc-x').count())===1);
await p.fill('#allRecus .rc-q','Mensualité');await p.waitForTimeout(200);step('Admin : recherche dans les reçus',(await p.locator('#allRecus a.rc-item').count())>=1&&(await p.locator('#allRecus a.rc-item').filter({hasText:'Commande'}).count())===0);
await loginAs('teacher','yao@test.ci');await go('versements.html');await p.waitForTimeout(1200);step('Enseignant : section des reçus de versements',(await p.textContent('#mesRecus')).includes('Reçus de versements'));
// 10. Visiteur : formulaire de contact
await logout();await go('contact.html');await p.fill('input[name=name]','Visiteur');await p.fill('input[name=email]','v@test.ci');
const so=await p.$$eval('select[name=subject] option',o=>o.map(x=>x.value||x.textContent).filter(Boolean));await p.selectOption('select[name=subject]',{index:1});await p.fill('textarea[name=message]','Bonjour');
await p.click('#contact-form button[type=submit]');await p.waitForTimeout(500);
d=await db();step('Formulaire de contact',(d.contact_messages||[]).length===1);
console.log('\nErreurs JavaScript :',errs.length?errs:'aucune');console.log('Étapes en échec :',issues.length?issues:'aucune');process.exitCode=issues.length||errs.length?1:0;
await b.close();
