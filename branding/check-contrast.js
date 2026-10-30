// Run in browser console after login. Repeat with menus and filters open.
(() => {
  const luminance = color => color.match(/[0-9.]+/g).slice(0, 3).map(Number)
    .map(value => (value /= 255) <= .04045 ? value / 12.92 : ((value + .055) / 1.055) ** 2.4)
    .reduce((sum, value, index) => sum + value * [.2126, .7152, .0722][index], 0);
  const failures = [];
  const documents = [document, ...[...document.querySelectorAll('iframe')]
    .map(frame => { try { return frame.contentDocument; } catch { return null; } }).filter(Boolean)];
  for (const doc of documents) {
    const view = doc.defaultView;
    for (const element of doc.querySelectorAll('a, button, label, th, span, scrm-label')) {
      if (element.children.length || !element.getClientRects().length || element.closest('[disabled], [aria-disabled="true"]')) continue;
      const text = element.textContent.trim();
      if (!text) continue;
      let parent = element;
      let background = view.getComputedStyle(parent).backgroundColor;
      while (background === 'rgba(0, 0, 0, 0)' && parent.parentElement) {
        parent = parent.parentElement;
        background = view.getComputedStyle(parent).backgroundColor;
      }
      if (background === 'rgba(0, 0, 0, 0)') background = 'rgb(255,255,255)';
      const style = view.getComputedStyle(element);
      const foreground = luminance(style.color), back = luminance(background);
      const ratio = (Math.max(foreground, back) + .05) / (Math.min(foreground, back) + .05);
      const large = parseFloat(style.fontSize) >= 24 || (parseFloat(style.fontSize) >= 18.66 && parseInt(style.fontWeight) >= 700);
      if (ratio < (large ? 3 : 4.5)) failures.push({ text: text.slice(0, 60), ratio: +ratio.toFixed(2), color: style.color, background, class: element.className });
    }
  }
  console.assert(!failures.length, 'Text contrast failures', failures);
  return failures;
})();
