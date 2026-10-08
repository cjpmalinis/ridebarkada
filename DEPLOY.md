# IMPORTANT GitHub Pages deployment

The screenshot you sent shows the browser is loading `index.html` but NOT loading `styles.css` (the page is using the browser default styles).

For the fixed version, upload/replace BOTH `index.html` and `styles.css` at the repository root. The new `index.html` also contains an inline CSS copy as a fallback, so the passenger page will remain styled even if GitHub Pages briefly caches/misses the CSS file.

Keep `config.js` at the repository root too.

Live URL: https://cjpmalinis.github.io/ridebarkada/
