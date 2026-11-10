{{flutter_js}}
{{flutter_build_config}}

window.addEventListener('flutter-first-frame', () => {
  const splash = document.getElementById('bootstrap-splash');
  if (!splash) return;

  splash.classList.add('is-hidden');
  window.setTimeout(() => splash.remove(), 250);
});

_flutter.loader.load({
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  },
});
