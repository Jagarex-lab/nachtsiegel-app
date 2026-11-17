// ORAFOLD_APP_MODE_BEGIN
// Presentation only: Safari's orientation APIs never decide arena geometry.
(() => {
 const app = {version:0,status:'',installPrompt:null};
 const standalone = () => !!(window.matchMedia?.('(display-mode: standalone)').matches || navigator.standalone === true);
 const ios = () => /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
 const change = message => { if (message !== undefined) app.status=message;app.version++; };
 const state = () => ({version:app.version,standalone:standalone(),ios:ios(),
  fullscreen:!!document.fullscreenElement,
  fullscreenSupported:typeof document.documentElement.requestFullscreen === 'function' && document.fullscreenEnabled !== false,
  installAvailable:!!app.installPrompt,status:app.status});
 window.orafoldApp = {
  state,
  async toggleFullscreen() {
   if (document.fullscreenElement) {
    try {await document.exitFullscreen();change('Vollbild beendet.');}
    catch (_) {change('Vollbild konnte nicht beendet werden. Verwende die Browsersteuerung.');}
   } else if (!state().fullscreenSupported) {
    change(ios() ? 'Auf iPhone und iPad: In Safari über Teilen → Zum Home-Bildschirm als Web-App öffnen.' : 'Dieser Browser bietet keinen Vollbildmodus. Die normale Ansicht bleibt spielbar.');
   } else {
    try {await document.documentElement.requestFullscreen();change('Vollbild aktiv.');}
    catch (_) {change('Vollbild wurde vom Browser nicht freigegeben. Erneut antippen oder die normale Ansicht verwenden.');}
   }
   return state();
  },
  async install() {
   const prompt=app.installPrompt;
   if (!prompt) {change(standalone() ? 'ORAFOLD läuft bereits als Web-App.' : ios() ? 'Safari: Teilen → Zum Home-Bildschirm → Als Web-App öffnen.' : 'Im Browsermenü „App installieren“ oder „Zum Startbildschirm“ wählen, sofern angeboten.');return state();}
   app.installPrompt=null;
   try {await prompt.prompt();const result=await prompt.userChoice;change(result?.outcome === 'accepted' ? 'Installation angefragt. Öffne ORAFOLD anschließend über das App-Symbol.' : 'Installation abgebrochen. Das Spiel bleibt im Browser verfügbar.');}
   catch (_) {change('Installation nicht verfügbar. Verwende das Browsermenü oder spiele im Browser weiter.');}
   return state();
  }
 };
 window.addEventListener('beforeinstallprompt',event=>{event.preventDefault();app.installPrompt=event;change();});
 window.addEventListener('appinstalled',()=>{app.installPrompt=null;change('ORAFOLD wurde als Web-App installiert.');});
 document.addEventListener('fullscreenchange',()=>{change();window.dispatchEvent(new Event('resize'));});
 window.matchMedia?.('(display-mode: standalone)').addEventListener?.('change',()=>change());
 // The exporter supplies this marker only for a complete, commit-addressed
 // Alpha package. Missing/denied service workers never block game startup.
 const worker=document.querySelector('meta[name="orafold-worker"]')?.content;
 if (worker && 'serviceWorker' in navigator && window.isSecureContext) {
  window.addEventListener('load',()=>{navigator.serviceWorker.register(worker,{scope:'./',updateViaCache:'none'}).then(registration=>registration.update()).catch(()=>change('Web-App-Installation eingeschränkt; das Spiel bleibt online im Browser verfügbar.'));},{once:true});
 }
})();
// ORAFOLD_APP_MODE_END
