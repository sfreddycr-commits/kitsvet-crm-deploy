// Run in browser console while loading, or with a .sk-cube-grid preview present.
(() => {
    const loader = document.querySelector('.sk-cube-grid');
    if (!loader) throw new Error('Loader not present');
    const ring = getComputedStyle(loader, '::before');
    const label = getComputedStyle(loader, '::after');
    console.assert(ring.borderTopColor === 'rgb(23, 84, 139)', 'Brand blue missing');
    console.assert(ring.borderRightColor === 'rgb(62, 139, 82)', 'Brand green missing');
    console.assert(label.content.includes('Cargando'), 'Loading label missing');
    console.assert([...loader.children].every(e => getComputedStyle(e).display === 'none'), 'Old cubes visible');
    console.assert(ring.animationName === (matchMedia('(prefers-reduced-motion: reduce)').matches ? 'none' : 'kv-spinner-turn'), 'Motion preference ignored');
})();
