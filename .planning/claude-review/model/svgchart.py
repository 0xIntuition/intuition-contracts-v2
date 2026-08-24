"""Tiny dependency-free SVG chart helpers (light theme, readable on GitHub)."""
import math

PAL = ["#2563eb", "#dc2626", "#16a34a", "#d97706", "#7c3aed", "#0891b2", "#db2777", "#65a30d",
       "#ea580c", "#4f46e5", "#0d9488", "#be123c", "#854d0e"]
FONT = "font-family='ui-sans-serif,system-ui,-apple-system,Segoe UI,Helvetica,Arial' "


def _esc(s):
    return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def _nice_ticks(lo, hi, n=5):
    if hi == lo:
        hi = lo + 1
    span = hi - lo
    raw = span / n
    mag = 10 ** math.floor(math.log10(raw))
    for m in (1, 2, 2.5, 5, 10):
        step = m * mag
        if span / step <= n + 1:
            break
    start = math.floor(lo / step) * step
    ticks = []
    t = start
    while t <= hi + step * 1e-9:
        ticks.append(round(t, 10))
        t += step
    return ticks


def fmt(v):
    if abs(v) >= 1e6:
        return f"{v/1e6:.1f}M"
    if abs(v) >= 1e3:
        return f"{v/1e3:.0f}k" if abs(v) >= 1e4 else f"{v/1e3:.1f}k"
    if abs(v) >= 100:
        return f"{v:.0f}"
    if abs(v) >= 1:
        return f"{v:.1f}"
    return f"{v:.2f}"


class Chart:
    def __init__(self, w=860, h=420, title="", subtitle="", ml=70, mr=30, mt=None, mb=60, legend_rows=1):
        self.w, self.h, self.title, self.subtitle = w, h, title, subtitle
        self.ml, self.mr, self.mb = ml, mr, mb
        self.mt = mt if mt is not None else 56 + 15 * legend_rows
        self.parts = []
        self._legend_n = 0

    @property
    def pw(self):
        return self.w - self.ml - self.mr

    @property
    def ph(self):
        return self.h - self.mt - self.mb

    def header(self):
        out = [f"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 {self.w} {self.h}' width='{self.w}' height='{self.h}' {FONT}>",
               f"<rect width='{self.w}' height='{self.h}' fill='#ffffff'/>",
               f"<text x='{self.ml}' y='26' font-size='16' font-weight='600' fill='#111827'>{_esc(self.title)}</text>"]
        if self.subtitle:
            out.append(f"<text x='{self.ml}' y='44' font-size='12' fill='#6b7280'>{_esc(self.subtitle)}</text>")
        return out

    def axes(self, x0, x1, y0, y1, xlabel="", ylabel="", xticks=None, xfmt=None, yfmt=fmt, ylog=False):
        self.x0, self.x1, self.y0, self.y1, self.ylog = x0, x1, y0, y1, ylog
        p = []
        yt = _nice_ticks(y0, y1) if not ylog else [10 ** e for e in range(math.floor(math.log10(max(y0, 1e-9))), math.ceil(math.log10(y1)) + 1)]
        for t in yt:
            if t < y0 - 1e-9 or t > y1 + 1e-9:
                continue
            y = self.Y(t)
            p.append(f"<line x1='{self.ml}' x2='{self.ml+self.pw}' y1='{y:.1f}' y2='{y:.1f}' stroke='#e5e7eb'/>")
            p.append(f"<text x='{self.ml-8}' y='{y+4:.1f}' font-size='11' text-anchor='end' fill='#6b7280'>{_esc(yfmt(t))}</text>")
        xt = xticks if xticks is not None else _nice_ticks(x0, x1, 8)
        for t in xt:
            x = self.X(t)
            lab = xfmt(t) if xfmt else fmt(t)
            p.append(f"<text x='{x:.1f}' y='{self.mt+self.ph+16}' font-size='11' text-anchor='middle' fill='#6b7280'>{_esc(lab)}</text>")
        p.append(f"<line x1='{self.ml}' x2='{self.ml+self.pw}' y1='{self.mt+self.ph}' y2='{self.mt+self.ph}' stroke='#9ca3af'/>")
        p.append(f"<line x1='{self.ml}' x2='{self.ml}' y1='{self.mt}' y2='{self.mt+self.ph}' stroke='#9ca3af'/>")
        if xlabel:
            p.append(f"<text x='{self.ml+self.pw/2}' y='{self.h-14}' font-size='12' text-anchor='middle' fill='#374151'>{_esc(xlabel)}</text>")
        if ylabel:
            p.append(f"<text transform='translate(16,{self.mt+self.ph/2}) rotate(-90)' font-size='12' text-anchor='middle' fill='#374151'>{_esc(ylabel)}</text>")
        self.parts += p

    def X(self, v):
        return self.ml + (v - self.x0) / (self.x1 - self.x0) * self.pw

    def Y(self, v):
        if self.ylog:
            lv = math.log10(max(v, 1e-12))
            return self.mt + self.ph - (lv - math.log10(max(self.y0, 1e-12))) / (math.log10(self.y1) - math.log10(max(self.y0, 1e-12))) * self.ph
        return self.mt + self.ph - (v - self.y0) / (self.y1 - self.y0) * self.ph

    def line(self, xs, ys, color, label=None, width=2, dash=None, step=False, marker=False):
        pts = []
        for i, (x, y) in enumerate(zip(xs, ys)):
            if step and i > 0:
                pts.append(f"{self.X(x):.1f},{self.Y(ys[i-1]):.1f}")
            pts.append(f"{self.X(x):.1f},{self.Y(y):.1f}")
        d = f" stroke-dasharray='{dash}'" if dash else ""
        self.parts.append(f"<polyline points='{' '.join(pts)}' fill='none' stroke='{color}' stroke-width='{width}'{d}/>")
        if marker:
            for x, y in zip(xs, ys):
                self.parts.append(f"<circle cx='{self.X(x):.1f}' cy='{self.Y(y):.1f}' r='3' fill='{color}'/>")
        if label:
            self._legend(label, color, dash)

    def bars(self, xs, ys, color, label=None, width=None, offset=0.0, group=1, base=None):
        n = len(xs)
        bw = (self.pw / max(n, 1)) * 0.7 / group if width is None else width
        for i, (x, y) in enumerate(zip(xs, ys)):
            b = 0 if base is None else base[i]
            y0 = self.Y(b)
            y1 = self.Y(b + y)
            top, hgt = min(y0, y1), abs(y1 - y0)
            cx = self.X(x) - (bw * group) / 2 + offset * bw
            self.parts.append(f"<rect x='{cx:.1f}' y='{top:.1f}' width='{bw:.1f}' height='{hgt:.1f}' fill='{color}' opacity='0.9'/>")
        if label:
            self._legend(label, color)

    def text(self, x, y, s, size=11, color="#374151", anchor="start", weight="400"):
        self.parts.append(f"<text x='{x:.1f}' y='{y:.1f}' font-size='{size}' fill='{color}' text-anchor='{anchor}' font-weight='{weight}'>{_esc(s)}</text>")

    def vline(self, xv, color="#9ca3af", dash="4 3", label=None):
        x = self.X(xv)
        self.parts.append(f"<line x1='{x:.1f}' x2='{x:.1f}' y1='{self.mt}' y2='{self.mt+self.ph}' stroke='{color}' stroke-dasharray='{dash}'/>")
        if label:
            self.text(x + 3, self.mt + 12, label, 10, color)

    def hline(self, yv, color="#9ca3af", dash="4 3", label=None):
        y = self.Y(yv)
        self.parts.append(f"<line x1='{self.ml}' x2='{self.ml+self.pw}' y1='{y:.1f}' y2='{y:.1f}' stroke='{color}' stroke-dasharray='{dash}'/>")
        if label:
            self.text(self.ml + self.pw - 3, y - 4, label, 10, color, anchor="end")

    def _legend(self, label, color, dash=None):
        i = self._legend_n
        self._legend_n += 1
        x = self.ml + 8 + (i % 4) * (self.pw / 4)
        y = 56 + (i // 4) * 15
        d = f" stroke-dasharray='{dash}'" if dash else ""
        self.parts.append(f"<line x1='{x}' x2='{x+18}' y1='{y}' y2='{y}' stroke='{color}' stroke-width='3'{d}/>")
        self.parts.append(f"<text x='{x+22}' y='{y+4}' font-size='11' fill='#374151'>{_esc(label)}</text>")

    def render(self, path):
        out = self.header() + self.parts + ["</svg>"]
        with open(path, "w") as f:
            f.write("\n".join(out))


def heatmap(path, matrix, row_labels, col_labels, title, subtitle="", xlabel="", ylabel="", cell=40, fmtv=lambda v: f"{v:.0%}" if v else ""):
    rows, cols = len(matrix), len(matrix[0])
    ml, mt = 90, 70
    w, h = ml + cols * cell + 30, mt + rows * cell + 50
    vmax = max(max(r) for r in matrix) or 1
    out = [f"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 {w} {h}' width='{w}' height='{h}' {FONT}>",
           f"<rect width='{w}' height='{h}' fill='#ffffff'/>",
           f"<text x='{ml}' y='26' font-size='16' font-weight='600' fill='#111827'>{_esc(title)}</text>",
           f"<text x='{ml}' y='44' font-size='12' fill='#6b7280'>{_esc(subtitle)}</text>"]
    for i, r in enumerate(matrix):
        out.append(f"<text x='{ml-8}' y='{mt+i*cell+cell/2+4}' font-size='11' text-anchor='end' fill='#374151'>{_esc(row_labels[i])}</text>")
        for j, v in enumerate(r):
            a = 0.08 + 0.85 * (v / vmax) if v else 0
            fill = f"rgba(37,99,235,{a:.2f})" if v else "#f9fafb"
            out.append(f"<rect x='{ml+j*cell}' y='{mt+i*cell}' width='{cell-1}' height='{cell-1}' fill='{fill}' stroke='#e5e7eb'/>")
            if v:
                col = "#ffffff" if a > 0.55 else "#111827"
                out.append(f"<text x='{ml+j*cell+cell/2}' y='{mt+i*cell+cell/2+4}' font-size='10' text-anchor='middle' fill='{col}'>{_esc(fmtv(v))}</text>")
    for j, c in enumerate(col_labels):
        out.append(f"<text x='{ml+j*cell+cell/2}' y='{mt-8}' font-size='11' text-anchor='middle' fill='#374151'>{_esc(c)}</text>")
    if xlabel:
        out.append(f"<text x='{ml+cols*cell/2}' y='{h-12}' font-size='12' text-anchor='middle' fill='#374151'>{_esc(xlabel)}</text>")
    if ylabel:
        out.append(f"<text transform='translate(18,{mt+rows*cell/2}) rotate(-90)' font-size='12' text-anchor='middle' fill='#374151'>{_esc(ylabel)}</text>")
    out.append("</svg>")
    open(path, "w").write("\n".join(out))


def ladder(path, edges, dep, wd, title, subtitle="", marks=None):
    """Horizontal tier ladder: each band as a segment scaled by width (log-ish compress via sqrt for legibility)."""
    n = len(edges)
    w, h = 960, 300
    ml, mr = 40, 40
    mt = 80
    widths = [edges[0]] + [edges[i] - edges[i - 1] for i in range(1, n)]
    # use proportional widths but with a floor so small bands stay readable
    tot = sum(widths)
    minw = 46
    pw = w - ml - mr
    raw = [wi / tot * pw for wi in widths]
    extra = sum(max(0, minw - r) for r in raw)
    big = sum(r for r in raw if r > minw)
    scaled = [max(minw, r) if r < minw else r - extra * (r / big) for r in raw]
    out = [f"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 {w} {h}' width='{w}' height='{h}' {FONT}>",
           f"<rect width='{w}' height='{h}' fill='#ffffff'/>",
           f"<text x='{ml}' y='26' font-size='16' font-weight='600' fill='#111827'>{_esc(title)}</text>",
           f"<text x='{ml}' y='44' font-size='12' fill='#6b7280'>{_esc(subtitle)}</text>"]
    x = ml
    for i in range(n):
        sw = scaled[i]
        a = 0.15 + 0.7 * i / (n - 1)
        out.append(f"<rect x='{x:.1f}' y='{mt}' width='{sw:.1f}' height='70' fill='rgba(37,99,235,{a:.2f})' stroke='#ffffff'/>")
        col = "#ffffff" if a > 0.5 else "#111827"
        out.append(f"<text x='{x+sw/2:.1f}' y='{mt+20}' font-size='12' font-weight='600' text-anchor='middle' fill='{col}'>T{i}</text>")
        out.append(f"<text x='{x+sw/2:.1f}' y='{mt+38}' font-size='10' text-anchor='middle' fill='{col}'>in {dep[i]/100:.1f}%</text>")
        out.append(f"<text x='{x+sw/2:.1f}' y='{mt+52}' font-size='10' text-anchor='middle' fill='{col}'>out {wd[i]/100:.1f}%</text>")
        lab = f"{edges[i]/1e18:,.0f}" if i < n - 1 else "∞"
        out.append(f"<text x='{x+sw:.1f}' y='{mt+88}' font-size='10' text-anchor='middle' fill='#374151'>{_esc(lab)}</text>")
        wl = f"w={widths[i]/1e18:,.0f}" if i < n - 1 else "terminal"
        out.append(f"<text x='{x+sw/2:.1f}' y='{mt+104}' font-size='9' text-anchor='middle' fill='#6b7280'>{_esc(wl)}</text>")
        x += sw
    out.append(f"<text x='{ml}' y='{mt+88}' font-size='10' text-anchor='middle' fill='#374151'>0</text>")
    out.append(f"<text x='{ml}' y='{mt+140}' font-size='11' fill='#6b7280'>cumulative net vault stake (TRUST) — bands are [lower, upper); the top tier is terminal and unbounded. Segment widths are compressed for legibility.</text>")
    out.append("</svg>")
    open(path, "w").write("\n".join(out))
