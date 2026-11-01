// Hero: Pan graphing on its own. An equation is typed, its curve draws in, its slider sweeps, then the next one. Decoration only.
(function () {
  var svg = document.getElementById('plane'), list = document.getElementById('eqs');
  if (!svg || !list) return;
  var NS = 'http://www.w3.org/2000/svg', still = matchMedia('(prefers-reduced-motion: reduce)').matches;
  var COLORS = ['#0b6ba8', '#d98a00', '#2a9d8f'];
  var EQS = [
    ['y = sin(x + a)', function (x, a) { return 2 * Math.sin(x + a * 2); }],
    ['y = a·x² − 2', function (x, a) { return a * .5 * x * x - 2; }],
    ['y = 2cos(a·x)', function (x, a) { return 2 * Math.cos(a * x); }],
    ['y = x³/8 − a·x', function (x, a) { return x * x * x / 8 - a * x; }],
    ['y = 3e^(−x²/a)', function (x, a) { return 3 * Math.exp(-x * x / (a * 2 + .4)); }],
    ['y = a·sin(3x)/x', function (x, a) { return x === 0 ? a * 3 : a * Math.sin(3 * x) / x; }]
  ];
  var W, H, U, live = [], k = 0;
  function el(t, a) { var e = document.createElementNS(NS, t); for (var n in a) e.setAttribute(n, a[n]); return e; }
  function grid() {
    W = svg.clientWidth; H = svg.clientHeight; U = W < 700 ? 40 : 64;
    svg.setAttribute('viewBox', '0 0 ' + W + ' ' + H); svg.textContent = '';
    var cx = W / 2, cy = H / 2, d = '';
    for (var x = cx % U; x < W; x += U) d += 'M' + x + ' 0V' + H;
    for (var y = cy % U; y < H; y += U) d += 'M0 ' + y + 'H' + W;
    svg.appendChild(el('path', { d: d, class: 'g' }));
    svg.appendChild(el('path', { d: 'M' + cx + ' 0V' + H + 'M0 ' + cy + 'H' + W, class: 'ax' }));
    live.forEach(function (c) { svg.appendChild(c.path); });
  }
  function path(f, a, upto) {
    var cx = W / 2, cy = H / 2, d = '', pen = false;
    for (var px = 0; px <= W * upto; px += 3) {
      var y = f((px - cx) / U, a), py = cy - y * U;
      if (!isFinite(py) || py < -H || py > 2 * H) { pen = false; continue; }
      d += (pen ? 'L' : 'M') + px.toFixed(1) + ' ' + py.toFixed(1); pen = true;
    }
    return d;
  }
  function add() {
    var e = EQS[k % EQS.length], color = COLORS[k % COLORS.length]; k++;
    var chip = document.createElement('div'); chip.className = 'eq';
    var dot = document.createElement('i'), txt = document.createElement('span'), val = document.createElement('small');
    dot.style.background = color; chip.append(dot, txt, val); list.appendChild(chip);
    var c = { f: e[1], path: el('path', { class: 'c', stroke: color }), chip: chip, val: val, t0: 0, a: 1 };
    svg.appendChild(c.path); live.push(c);
    if (live.length > 3) { var old = live.shift(); old.path.remove(); old.chip.remove(); }
    live.forEach(function (x) { x.chip.classList.toggle('old', x !== c); x.path.style.opacity = x === c ? 1 : .45; });
    if (still) { txt.textContent = e[0]; c.path.setAttribute('d', path(c.f, 1, 1)); val.textContent = 'a = 1'; return; }
    var i = 0;
    (function type() { txt.textContent = e[0].slice(0, ++i); if (i < e[0].length) setTimeout(type, 70 + Math.random() * 60); else c.t0 = performance.now(); })();
  }
  function frame(now) {
    live.forEach(function (c) {
      if (!c.t0) return;
      var t = (now - c.t0) / 1000, upto = Math.min(1, t / 1.4);
      c.a = 1 + .6 * Math.sin(Math.max(0, t - 1.4) * .9);
      c.path.setAttribute('d', path(c.f, c.a, upto));
      c.val.textContent = 'a = ' + c.a.toFixed(2);
    });
    requestAnimationFrame(frame);
  }
  grid(); add();
  if (still) { add(); add(); return; }
  setInterval(add, 5200);
  requestAnimationFrame(frame);
  addEventListener('resize', grid);

  // Parallax: the plane drifts at 0.45, the copy lifts at 0.2 and fades.
  var bg = document.querySelector('.phero .hero-bg'), copy = document.querySelector('.phero .hero-copy'), r = 0;
  addEventListener('scroll', function () {
    if (r) return;
    r = requestAnimationFrame(function () {
      r = 0; var y = scrollY, h = innerHeight; if (y > h * 1.2) return;
      bg.style.setProperty('--py', (y * .45) + 'px');
      copy.style.transform = 'translate3d(0,' + (y * .2) + 'px,0)'; copy.style.opacity = Math.max(0, 1 - y / (h * .7));
    });
  }, { passive: true });
})();
