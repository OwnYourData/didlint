// applies a theme the visitor picked before, ahead of the first paint
try {
  var t = localStorage.getItem("uniresolver-theme");
  if (t === "light" || t === "dark") document.documentElement.setAttribute("data-theme", t);
} catch (e) {}
