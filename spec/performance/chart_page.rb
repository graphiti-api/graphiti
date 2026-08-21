require "json"
require "fileutils"
require_relative "scenarios"
# Guarded because measure_releases may already be running as the main script.
require_relative "measure_releases" unless defined?(MeasureReleases)

# Renders performance_history.tsv to tmp/performance.html and opens it.
module ChartPage
  ROOT = File.expand_path("../..", __dir__)
  HISTORY = File.expand_path("performance_history.tsv", __dir__)
  OUTPUT = File.join(ROOT, "tmp", "performance.html")
  WORKING_TREE = "working tree"

  module_function

  # measured skips the probe when the caller already has the numbers.
  def run(open: true, current: true, measured: nil)
    abort "no #{HISTORY}, run rake performance:record_all" unless File.exist?(HISTORY)

    rows = measurements
    rows += measured || working_tree if current
    FileUtils.mkdir_p(File.dirname(OUTPUT))
    File.write(OUTPUT, page(rows))
    launch if open
    OUTPUT
  end

  def as_rows(measured)
    measured.map do |_, ruby, mode, scenario, phase, allocations|
      {
        version: WORKING_TREE, ruby: ruby, concurrency: mode,
        scenario: scenario, phase: phase, count: allocations.to_i
      }
    end
  end

  # Plotted as one more release so the branch you are on sits beside the history.
  def working_tree
    MeasureReleases::MODES.flat_map do |mode|
      measured = MeasureReleases.measure_in(MeasureReleases::ROOT, mode) || []
      measured.map do |scenario, phase, allocations|
        {
          version: WORKING_TREE, ruby: MeasureReleases::RUBY, concurrency: mode,
          scenario: scenario, phase: phase, count: allocations.to_i
        }
      end
    end
  end

  def measurements
    File.readlines(HISTORY, chomp: true).drop(1).reject(&:empty?).map do |line|
      version, ruby, concurrency, scenario, phase, allocations = line.split("\t")
      {
        version: version, ruby: ruby, concurrency: concurrency,
        scenario: scenario, phase: phase, count: allocations.to_i
      }
    end
  end

  def launch
    opener = if RUBY_PLATFORM.include?("darwin")
      "open"
    else
      (system("which xdg-open > /dev/null 2>&1") ? "xdg-open" : nil)
    end
    opener ? system(opener, OUTPUT) : puts("open it yourself, no opener found")
  end

  def page(rows)
    TEMPLATE
      .sub("__DATA__", JSON.generate(rows))
      .sub("__NAMES__", JSON.generate(Scenarios.descriptions))
  end

  TEMPLATE = <<~HTML
    <!doctype html>
    <html lang="en"><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>graphiti object allocations</title>
    <style>
    :root{
      --ground:#F5F6F8;--surface:#FFF;--ink:#161A21;--muted:#69727E;--line:#DEE2E8;
      --a:#1B6E8C;--b:#C25A1F;--good:#2C7A52;--bad:#A32A22;--grid:#E7EAEF;--band:#EEF1F5;
    }
    @media (prefers-color-scheme:dark){:root{
      --ground:#11141A;--surface:#181C24;--ink:#E6E9EE;--muted:#8A939F;--line:#2A303B;
      --a:#4FA8C7;--b:#E38A4F;--good:#5FBF88;--bad:#E0736A;--grid:#232936;--band:#1D222B;
    }}
    *{box-sizing:border-box}
    body{margin:0;background:var(--ground);color:var(--ink);
      font:15px/1.55 ui-sans-serif,system-ui,-apple-system,"Segoe UI",sans-serif}
    .wrap{max-width:1100px;margin:0 auto;padding:40px 24px 64px;display:flex;flex-direction:column;gap:22px}
    h1{font-size:26px;letter-spacing:-.02em;margin:0}
    .sub{color:var(--muted);margin:6px 0 0;font-size:14px}
    .controls{display:flex;flex-wrap:wrap;gap:10px 20px;align-items:flex-end}
    label{display:flex;flex-direction:column;gap:5px;font-size:11px;letter-spacing:.1em;
      text-transform:uppercase;color:var(--muted)}
    select{font:14px ui-sans-serif,system-ui,sans-serif;padding:7px 9px;border:1px solid var(--line);
      border-radius:2px;background:var(--surface);color:var(--ink)}
    .card{background:var(--surface);border:1px solid var(--line);border-radius:3px;padding:16px 18px 10px}
    .cardhead{display:flex;justify-content:space-between;align-items:baseline;gap:14px;margin-bottom:6px}
    .cardtitle{font-size:13px;letter-spacing:.1em;text-transform:uppercase;color:var(--muted)}
    .final{font:13px ui-monospace,SFMono-Regular,Menlo,monospace;color:var(--muted);font-variant-numeric:tabular-nums}
    .legend{display:flex;gap:18px;font-size:13px;color:var(--muted);margin-bottom:4px;flex-wrap:wrap}
    .key{display:inline-flex;align-items:center;gap:7px}
    .sw{width:15px;height:3px;border-radius:2px}
    svg{display:block;width:100%;height:auto;overflow:visible}
    table{border-collapse:collapse;width:100%;font:12.5px ui-monospace,SFMono-Regular,Menlo,monospace;
      font-variant-numeric:tabular-nums}
    .tablewrap{overflow-x:auto;background:var(--surface);border:1px solid var(--line);border-radius:3px}
    th,td{padding:6px 12px;text-align:right;white-space:nowrap}
    th:first-child,td:first-child,th:nth-child(2),td:nth-child(2),th:nth-child(3),td:nth-child(3){text-align:left}
    thead th{background:var(--surface);border-bottom:1px solid var(--line);font-weight:600;
      color:var(--muted);font-size:10.5px;letter-spacing:.06em;text-transform:uppercase}
    tbody tr:nth-child(even){background:var(--band)}
    thead th{cursor:pointer;user-select:none}
    thead th:hover{color:var(--ink)}
    thead th:focus-visible{outline:2px solid var(--a);outline-offset:-2px}
    .arrow{display:inline-block;width:1em;text-align:center;opacity:.8}
    .up{color:var(--bad)}.down{color:var(--good)}
    </style></head><body><div class="wrap">
    <header><h1>graphiti object allocations</h1><p class="sub" id="sub"></p></header>
    <div class="controls">
      <label>view<select id="view"><option value="index">index, all scenarios</option></select></label>
    </div>
    <div class="legend" id="legend"></div>
    <div id="charts"></div>
    <div class="controls">
      <label>table<select id="tablerows">
        <option value="changes">changes only</option>
        <option value="all">all releases</option>
      </select></label>
    </div>
    <div class="tablewrap"><table id="tbl"><thead><tr>
      <th data-sort="release">release<span class="arrow"></span></th>
      <th data-sort="concurrency">concurrency<span class="arrow"></span></th>
      <th data-sort="ruby">ruby<span class="arrow"></span></th>
      <th data-sort="value">value<span class="arrow"></span></th>
      <th data-sort="change">change<span class="arrow"></span></th>
    </tr></thead><tbody></tbody></table></div>
    </div>
    <script>
    const ROWS = __DATA__;
    const NAMES = __NAMES__;
    const describe = id => NAMES[id] || id;
    const RUBIES = [...new Set(ROWS.map(r => r.ruby))].sort();
    const CONCS = [...new Set(ROWS.map(r => r.concurrency))].sort();
    const KEYS = [...new Set(ROWS.map(r => r.scenario + "\\u0000" + r.phase))].sort();
    const COLOR = {}; RUBIES.forEach((r,i) => COLOR[r] = i === 0 ? "var(--a)" : "var(--b)");
    const view = document.getElementById("view");
    KEYS.forEach(k => view.add(new Option(k.split("\\u0000").map((p,i) => i ? p : describe(p)).join(" \\u00b7 "), k)));

    const WORKING_TREE = "working tree";
    // One axis for every series, otherwise a working tree point on one ruby
    // shifts the other ruby's releases along by one.
    const VERSIONS = (() => {
      const seen = [];
      ROWS.forEach(r => { if(r.version !== WORKING_TREE && !seen.includes(r.version)) seen.push(r.version); });
      if(ROWS.some(r => r.version === WORKING_TREE)) seen.push(WORKING_TREE);
      return seen;
    })();
    const BASE_RUBY = RUBIES[0], BASE_CONC = CONCS[0];

    function valueAt(ruby, concurrency, version, key){
      const [scenario, phase] = key.split("\\u0000");
      const row = ROWS.find(r => r.ruby===ruby && r.concurrency===concurrency
        && r.version===version && r.scenario===scenario && r.phase===phase);
      return row && row.count;
    }

    // One shared denominator, otherwise each series divides out its own offset
    // and every ruby lands on the same line.
    function seriesFor(ruby, concurrency){
      const versions = VERSIONS;
      const pick = (v, key) => valueAt(ruby, concurrency, v, key);
      if (view.value !== "index") {
        return {versions, points: versions.map(v => pick(v, view.value)), unit: "objects"};
      }
      const base = KEYS.map(k => valueAt(BASE_RUBY, BASE_CONC, VERSIONS[0], k));
      const points = versions.map(v => {
        const ratios = KEYS.map((k,i) => { const n = pick(v,k); return (n && base[i]) ? n/base[i] : null; })
          .filter(x => x != null);
        return ratios.length ? ratios.reduce((a,b)=>a+b,0)/ratios.length : null;
      });
      return {versions, points, unit: "index"};
    }

    // Both panels share a scale, which is the point of stacking them.
    function draw(){
      const panels = CONCS.map(c => ({concurrency: c, series: RUBIES.map(r => seriesFor(r, c))}));
      const flat = panels.flatMap(p => p.series.flatMap(s => s.points)).filter(n => n != null);
      const lo = Math.min(...flat), hi = Math.max(...flat);
      const pad = (hi-lo)*0.12 || (hi*0.01 || 1);
      const unit = panels[0].series[0].unit;
      const fmt = v => unit === "index" ? v.toFixed(3) : Math.round(v).toLocaleString();

      document.getElementById("charts").innerHTML = panels.map(p => {
        const last = p.series.map((s, i) => {
          const point = [...s.points].reverse().find(x => x != null);
          return point == null ? null : `${RUBIES[i]} ${fmt(point)}`;
        }).filter(Boolean).join("  |  ");
        return `<div class="card"><div class="cardhead">
          <span class="cardtitle">concurrency ${p.concurrency}</span>
          <span class="final">${last}</span></div>
          <svg viewBox="0 0 1000 300" role="img" aria-label="allocations, concurrency ${p.concurrency}">
          ${panel(p, lo-pad, hi+pad, fmt)}</svg></div>`;
      }).join("");

      document.getElementById("legend").innerHTML = RUBIES.map(r =>
        `<span class="key"><span class="sw" style="background:${COLOR[r]}"></span>ruby ${r}</span>`).join("");
      const n = panels[0].series[0].versions.length;
      document.getElementById("sub").textContent =
        `${KEYS.length} measurements \\u00b7 ${n} releases \\u00b7 shared scale` +
        (unit === "index" ? `, indexed to ruby ${BASE_RUBY} / ${BASE_CONC} / ${VERSIONS[0]}` : "");
      table(panels, fmt);
    }

    function panel(p, y0, y1, fmt){
      const W=1000,H=300,L=70,R=14,T=14,B=60;
      const versions = p.series[0].versions, n = versions.length;
      const X = i => L + i*(W-L-R)/(n-1);
      const Y = v => T + (1-(v-y0)/(y1-y0))*(H-T-B);
      let s = "";
      for(let g=0; g<=3; g++){
        const val = y0+(y1-y0)*g/3, y = Y(val);
        s += `<line x1="${L}" y1="${y}" x2="${W-R}" y2="${y}" stroke="var(--grid)"/>`;
        s += `<text x="${L-9}" y="${y+4}" text-anchor="end" fill="var(--muted)" font-size="11" font-family="ui-monospace,monospace">${fmt(val)}</text>`;
      }
      p.series.forEach((series, i) => {
        let d = "", started = false;
        series.points.forEach((v, idx) => { if(v==null) return; d += (started?" L":"M")+X(idx)+" "+Y(v); started = true; });
        s += `<path d="${d}" fill="none" stroke="${COLOR[RUBIES[i]]}" stroke-width="2"/>`;
        series.points.forEach((v, idx) => { if(v==null) return;
          s += `<circle cx="${X(idx)}" cy="${Y(v)}" r="2.4" fill="${COLOR[RUBIES[i]]}"><title>${versions[idx]} \\u00b7 ruby ${RUBIES[i]} \\u00b7 concurrency ${p.concurrency} \\u00b7 ${fmt(v)}</title></circle>`; });
      });
      versions.forEach((v, i) => {
        if(n > 16 && i % 3 !== 0 && i !== n-1) return;
        s += `<text x="${X(i)}" y="${H-B+15}" transform="rotate(-52 ${X(i)} ${H-B+15})" text-anchor="end" fill="var(--muted)" font-size="10" font-family="ui-monospace,monospace">${v.replace(/^v/,"")}</text>`;
      });
      return s;
    }

    // Release order is the meaningful default, so it is a sort like any other
    // rather than the unsorted state.
    let rows = [], sortBy = "release", ascending = true;

    function table(panels, fmt){
      rows = [];
      panels.forEach(p => p.series.forEach((series, i) => {
        let previous = null;
        series.versions.forEach((v, idx) => {
          const point = series.points[idx];
          if(point == null) return;
          const change = previous == null ? null : (point-previous)/previous;
          previous = point;
          rows.push({release: v, order: idx, concurrency: p.concurrency,
            ruby: RUBIES[i], value: point, change, text: fmt(point),
            moved: change != null && Math.abs(change) >= 0.005});
        });
      }));
      render();
    }

    function render(){
      const dir = ascending ? 1 : -1;
      const key = r => sortBy === "release" ? r.order
        : sortBy === "change" ? (r.change ?? 0)
        : sortBy === "value" ? r.value
        : r[sortBy];
      const shown = tablerows.value === "all" ? rows : rows.filter(r => r.moved);
      const sorted = [...shown].sort((a, b) => {
        const x = key(a), y = key(b);
        if(x === y) return a.order - b.order;
        return (typeof x === "string" ? x.localeCompare(y) : x - y) * dir;
      });
      document.querySelector("#tbl tbody").innerHTML = sorted.map(r => {
        const cls = !r.moved ? "" : r.change > 0 ? "up" : "down";
        const pct = r.change == null ? "\\u2014"
          : (r.change > 0 ? "+" : "") + (r.change*100).toFixed(1) + "%";
        return `<tr><td>${r.release}</td><td>${r.concurrency}</td><td>${r.ruby}</td><td>${r.text}</td><td class="${cls}">${pct}</td></tr>`;
      }).join("") || "<tr><td colspan='5'>no changes above 0.5%</td></tr>";

      document.querySelectorAll("#tbl thead th").forEach(th => {
        const mine = th.dataset.sort === sortBy;
        th.setAttribute("aria-sort", mine ? (ascending ? "ascending" : "descending") : "none");
        th.querySelector(".arrow").textContent = mine ? (ascending ? "\u2191" : "\u2193") : "";
      });
    }

    document.querySelectorAll("#tbl thead th").forEach(th => {
      th.tabIndex = 0;
      const go = () => {
        const column = th.dataset.sort;
        if(column === sortBy){ ascending = !ascending; }
        else { sortBy = column; ascending = column === "release"; }
        render();
      };
      th.onclick = go;
      th.onkeydown = e => { if(e.key === "Enter" || e.key === " "){ e.preventDefault(); go(); } };
    });

    const tablerows = document.getElementById("tablerows");
    tablerows.onchange = render;
    view.onchange = draw; draw();
    </script></body></html>
  HTML
end

if $PROGRAM_NAME == __FILE__
  path = ChartPage.run(open: !ARGV.include?("--no-open"), current: !ARGV.include?("--no-current"))
  puts "wrote #{path}"
end
