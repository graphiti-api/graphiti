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
  CHART_LIBRARY = File.expand_path("vendor/chart.umd.js", __dir__)

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
    measured.map do |_, ruby, mode, scenario, phase, allocations, milliseconds|
      row(WORKING_TREE, ruby, mode, scenario, phase, allocations, milliseconds, MeasureReleases.machine)
    end
  end

  def row(version, ruby, concurrency, scenario, phase, allocations, milliseconds, machine)
    {
      version: version, ruby: ruby, concurrency: concurrency,
      scenario: scenario, phase: phase, count: allocations.to_i,
      ms: milliseconds.to_s.empty? ? nil : milliseconds.to_f,
      machine: machine.to_s
    }
  end

  # Plotted as one more release so the branch you are on sits beside the history.
  def working_tree
    MeasureReleases::Progress.start(MeasureReleases::MODES.length * MeasureReleases.measurements_per_mode)
    MeasureReleases::MODES.flat_map { |mode|
      measured = MeasureReleases.measure_in(MeasureReleases::ROOT, mode) || []
      measured.map { |scenario, phase, allocations, milliseconds|
        row(WORKING_TREE, MeasureReleases::RUBY, mode, scenario, phase, allocations, milliseconds, MeasureReleases.machine)
      }
    }
  ensure
    MeasureReleases::Progress.finish
  end

  def measurements
    File.readlines(HISTORY, chomp: true).drop(1).reject(&:empty?).map do |line|
      cells = line.split("\t").first(8)
      row(*cells.fill(nil, cells.length...8))
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
    # Block form throughout: a replacement string would read \\1 and friends in
    # minified javascript and json as backreferences.
    TEMPLATE
      .sub("__DATA__") { JSON.generate(rows) }
      .sub("__NAMES__") { JSON.generate(Scenarios.descriptions) }
      .sub("__WAITING__") { JSON.generate(Scenarios.waiting) }
      .gsub("__NOISE__") { JSON.generate(NOISE_FLOOR) }
      .sub("__CHARTJS__") { File.read(CHART_LIBRARY) }
  end

  # Six repeats of the probe, worst measurement in each group rounded up: 1.7% where nothing waits, 3.7% where something does.
  NOISE_FLOOR = {quiet: 0.02, waiting: 0.04}.freeze

  TEMPLATE = <<~HTML
    <!doctype html>
    <html lang="en"><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>graphiti performance</title>
    <style>
    :root{
      --ground:#F5F6F8;--surface:#FFF;--ink:#161A21;--muted:#69727E;--line:#DEE2E8;
      --a:#1B6E8C;--b:#C25A1F;--c:#6A4C93;--d:#97266D;--good:#2C7A52;--bad:#A32A22;--grid:#E7EAEF;--band:#EEF1F5;
    }
    @media (prefers-color-scheme:dark){:root{
      --ground:#11141A;--surface:#181C24;--ink:#E6E9EE;--muted:#8A939F;--line:#2A303B;
      --a:#4FA8C7;--b:#E38A4F;--c:#A78BE0;--d:#DB86B8;--good:#5FBF88;--bad:#E0736A;--grid:#232936;--band:#1D222B;
    }}
    *{box-sizing:border-box}
    body{margin:0;background:var(--ground);color:var(--ink);
      font:15px/1.55 ui-sans-serif,system-ui,-apple-system,"Segoe UI",sans-serif}
    .wrap{max-width:1600px;margin:0 auto;padding:40px 24px 64px;display:flex;flex-direction:column;gap:22px}
    .panes{display:grid;grid-template-columns:minmax(0,1.1fr) minmax(0,1fr);gap:22px;align-items:start}
    @media (max-width:1180px){.panes{grid-template-columns:minmax(0,1fr)}}
    h1{font-size:26px;letter-spacing:-.02em;margin:0}
    .sub{color:var(--muted);margin:6px 0 0;font-size:14px}
    #charts{position:relative;height:400px}
    #counts{position:relative;height:170px;margin-top:6px}
    .controls{display:flex;flex-wrap:wrap;gap:10px 20px;align-items:flex-end}
    .tablebar{margin-bottom:10px}
    .bar{position:sticky;top:0;z-index:5;background:var(--ground);padding:14px 0 12px;
      border-bottom:1px solid var(--line);display:flex;flex-direction:column;gap:10px}
    label{display:flex;flex-direction:column;gap:5px;font-size:11px;letter-spacing:.1em;
      text-transform:uppercase;color:var(--muted)}
    select{font:14px ui-sans-serif,system-ui,sans-serif;padding:7px 9px;border:1px solid var(--line);
      border-radius:2px;background:var(--surface);color:var(--ink)}
    .card{background:var(--surface);border:1px solid var(--line);border-radius:3px;padding:16px 18px 10px}
    .cardhead{display:flex;justify-content:space-between;align-items:baseline;gap:14px;margin-bottom:6px}
    .cardtitle{font-size:13px;letter-spacing:.1em;text-transform:uppercase;color:var(--muted)}
    .final{font:13px ui-monospace,SFMono-Regular,Menlo,monospace;color:var(--muted);font-variant-numeric:tabular-nums}
    .legend{display:flex;gap:18px;font-size:13px;color:var(--muted);margin-bottom:4px;flex-wrap:wrap}
    .key{display:inline-flex;align-items:center;gap:7px;background:none;border:0;padding:0;
      font:inherit;color:inherit;cursor:pointer}
    .key.off{opacity:.45}
    .key.off .sw{background:transparent!important;box-shadow:inset 0 0 0 1px currentColor}
    .sw{width:15px;height:3px;border-radius:2px}
    svg.sw{width:16px;height:10px;border-radius:0;overflow:visible}
    svg{display:block;width:100%;height:auto;overflow:visible}
    table{border-collapse:collapse;width:100%;font:12.5px ui-monospace,SFMono-Regular,Menlo,monospace;
      font-variant-numeric:tabular-nums}
    .tablewrap{overflow:auto;max-height:calc(100vh - var(--barh, 0px) - 96px);
      background:var(--surface);border:1px solid var(--line);border-radius:3px}
    th,td{padding:6px 12px;text-align:right;white-space:nowrap}
    th:first-child,td:first-child,th:nth-child(2),td:nth-child(2),th:nth-child(3),td:nth-child(3){text-align:left}
    thead th{position:sticky;top:0;z-index:2;
      background:var(--surface);border-bottom:1px solid var(--line);font-weight:600;
      color:var(--muted);font-size:10.5px;letter-spacing:.06em;text-transform:uppercase}
    tbody tr:nth-child(even){background:var(--band)}
    thead th{cursor:pointer;user-select:none}
    thead th:hover{color:var(--ink)}
    thead th:focus-visible{outline:2px solid var(--a);outline-offset:-2px}
    .arrow{display:inline-block;width:1em;text-align:center;opacity:.8}
    .up{color:var(--bad)}.down{color:var(--good)}
    </style></head><body><div class="wrap">
    <header><h1>graphiti performance</h1><p class="sub" id="sub"></p></header>
    <div class="bar">
    <div class="controls">
      <label>ruby<select id="ruby"></select></label>
      <label>view<select id="view">
        <option value="index:io">index, waiting on a simulated database</option>
        <option value="index:cpu">index, graphiti's own work</option>
      </select></label>
      <label>baseline<select id="baseline"></select></label>
      <label>range<select id="range">
        <option value="10" selected>last 10</option>
        <option value="5">last 5</option>
        <option value="15">last 15</option>
        <option value="25">last 25</option>
        <option value="0">every release</option>
      </select></label>
      <label>prereleases<select id="prereleases">
        <option value="collapse">collapsed into the last of each version</option>
        <option value="show">shown</option>
      </select></label>
    </div>
    <div class="legend" id="legend"></div>
    </div>
    <div class="panes">
    <div class="card"><div class="cardhead"><span class="cardtitle"></span></div>
    <div id="charts"><canvas id="chart"></canvas></div>
    <div id="counts"><canvas id="countchart"></canvas></div></div>
    <div class="tablepane">
    <div class="controls tablebar">
      <label>metric<select id="metric">
        <option value="count">object allocations</option>
        <option value="ms">milliseconds, fastest pass</option>
      </select></label>
      <label>rows<select id="tablerows">
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
      <th data-sort="since" id="sincehead">since<span class="arrow"></span></th>
    </tr></thead><tbody></tbody></table></div>
    </div>
    </div>
    </div>
    <script>__CHARTJS__</script>
    <script>
    const ROWS = __DATA__;
    const NAMES = __NAMES__;
    // Averaging a scenario that waits together with one that does not would show
    // concurrency losing, dragged down by the scenarios it was never going to help.
    const WAITING = new Set(__WAITING__);
    const describe = id => NAMES[id] || id;
    // Sorted as versions, so a 3.10 would not land between 3.1 and 3.2.
    const RUBIES = [...new Set(ROWS.map(r => r.ruby))].sort((a, b) => {
      const [am, an] = a.split(".").map(Number), [bm, bn] = b.split(".").map(Number);
      return (am - bm) || (an - bn);
    });
    const CONCS = [...new Set(ROWS.map(r => r.concurrency))].sort();
    const KEYS = [...new Set(ROWS.map(r => r.scenario + "\\u0000" + r.phase))].sort();
    const view = document.getElementById("view");
    KEYS.forEach(k => view.add(new Option(k.split("\\u0000").map((p,i) => i ? p : describe(p)).join(" \\u00b7 "), k)));

    function shownKeys(){
      if(!view.value.startsWith("index")) return [view.value];
      const wanted = view.value === "index:io";
      return KEYS.filter(k => WAITING.has(k.split("\\u0000")[0]) === wanted);
    }

    const WORKING_TREE = "working tree";
    const RELEASES = (() => {
      const seen = [];
      ROWS.forEach(r => { if(r.version !== WORKING_TREE && !seen.includes(r.version)) seen.push(r.version); });
      return seen;
    })();
    const HAS_WORKING_TREE = ROWS.some(r => r.version === WORKING_TREE);
    const prereleases = document.getElementById("prereleases");
    // A prerelease run stands in for the version it led to.
    function axisVersions(){
      let list = RELEASES;
      if(prereleases.value === "collapse"){
        const last = new Map();
        RELEASES.forEach(v => last.set(v.split("-")[0], v));
        list = RELEASES.filter(v => last.get(v.split("-")[0]) === v);
      }
      const limit = Number(rangeChoice.value);
      if(limit) list = list.slice(-limit);
      return HAS_WORKING_TREE ? list.concat(WORKING_TREE) : list;
    }
    const BASE_CONC = CONCS[0];
    const rangeChoice = document.getElementById("range");
    const baselineChoice = document.getElementById("baseline");
    baselineChoice.add(new Option("earliest release measured", ""));
    RELEASES.forEach(v => baselineChoice.add(new Option(v, v)));
    // The newest stable release, so zero on the axis is what shipped rather
    // than a version picked at random.
    const PREFERRED = RELEASES.filter(v => !v.includes("-")).pop();
    if(PREFERRED) baselineChoice.value = PREFERRED;
    // The ruby on screen is its own denominator, so zero means that ruby.
    function baseline(){
      const candidates = baselineChoice.value ? [baselineChoice.value] : RELEASES;
      const rubies = [rubyChoice.value, ...RUBIES];
      for(const ruby of rubies) for(const version of candidates)
        if(KEYS.some(k => valueAt(ruby, BASE_CONC, version, k, TIMING) != null)) return {ruby, version};
      return {ruby: rubyChoice.value, version: candidates[0]};
    }

    // Measured by repeating the probe rather than read out of the history, since
    // a release is timed once and its own spread is not recorded.
    const NOISE = __NOISE__;

    function noiseFloor(){
      return shownKeys().some(k => WAITING.has(k.split("\\u0000")[0])) ? NOISE.waiting : NOISE.quiet;
    }

    const metric = document.getElementById("metric");
    const rubyChoice = document.getElementById("ruby");
    RUBIES.forEach(r => rubyChoice.add(new Option(`ruby ${r}`, r)));
    // Whichever ruby the working tree was measured on, since that is the run being looked at.
    const MEASURED = ROWS.find(r => r.version === WORKING_TREE);
    rubyChoice.value = MEASURED ? MEASURED.ruby : RUBIES[RUBIES.length - 1];

    // Fixed, so choosing what the table lists never redraws the chart.
    const TIMING = "ms";
    // Colour carries concurrency and shape the measure, so a bar and its line match.
    const CONC_COLOR = {};
    CONCS.forEach((c, i) => CONC_COLOR[c] = i === 0 ? "var(--a)" : "var(--b)");
    const SERIES_LABEL = {count: "allocations", ms: "milliseconds"};

    // Allocations are counted and mean the same anywhere. A timing only compares
    // within one box, so a row measured on another one has no millisecond to give.
    const HERE = (() => {
      const measured = ROWS.find(r => r.version === WORKING_TREE && r.machine);
      if(measured) return measured.machine;
      const seen = new Map();
      ROWS.forEach(r => r.machine && seen.set(r.machine, (seen.get(r.machine) || 0) + 1));
      return [...seen.entries()].sort((a, b) => b[1] - a[1]).map(e => e[0])[0];
    })();
    const ELSEWHERE = [...new Set(ROWS.filter(r => r.ms != null && r.machine && r.machine !== HERE)
      .map(r => r.machine))];

    function valueAt(ruby, concurrency, version, key, metricName){
      const [scenario, phase] = key.split("\\u0000");
      const row = ROWS.find(r => r.ruby===ruby && r.concurrency===concurrency
        && r.version===version && r.scenario===scenario && r.phase===phase);
      if(!row) return undefined;
      if(metricName !== "count" && row.machine && row.machine !== HERE) return undefined;
      return row[metricName];
    }

    function seriesFor(ruby, concurrency, metricName){
      const versions = axisVersions();
      const keys = shownKeys();
      const origin = baseline();
      // Both paths divide by the same number, so the gap between them is the pool's cost.
      const base = keys.map(k => valueAt(origin.ruby, CONCS[0], origin.version, k, metricName));
      const points = versions.map(v => {
        const ratios = keys.map((k, i) => {
          const n = valueAt(ruby, concurrency, v, k, metricName);
          return (n && base[i]) ? n/base[i] : null;
        }).filter(x => x != null);
        return ratios.length ? ratios.reduce((a,b) => a+b, 0)/ratios.length : null;
      });
      // What the ratio was computed from, so hovering gives a number too.
      const totals = versions.map(v => {
        const found = keys.map(k => valueAt(ruby, concurrency, v, k, metricName)).filter(n => n != null);
        return found.length ? found.reduce((a,b) => a+b, 0) : null;
      });
      const baseTotal = base.filter(n => n != null).reduce((a, b) => a+b, 0);
      return {ruby, concurrency, metric: metricName, versions, points, totals, baseTotal,
        unit: {count: "objects", ms: "ms"}[metricName],
        color: CONC_COLOR[concurrency],
        label: `${SERIES_LABEL[metricName]}, concurrency ${concurrency}`,
        noise: metricName === "count" ? 0 : noiseFloor()};
    }

    // A ratio of one is no change, so the axis needs no unit of its own.
    const asPercent = v => `${v >= 1 ? "+" : "\\u2212"}${(Math.abs(v-1)*100).toFixed(1)}%`;

    // Colours live in CSS variables, and a canvas needs the value, not the name.
    const resolved = name => getComputedStyle(document.documentElement).getPropertyValue(name).trim();
    const withAlpha = (hex, alpha) => {
      const value = hex.replace("#", "");
      const full = value.length === 3 ? value.split("").map(c => c+c).join("") : value;
      const [r, g, b] = [0, 2, 4].map(i => parseInt(full.slice(i, i+2), 16));
      return `rgba(${r}, ${g}, ${b}, ${alpha})`;
    };

    let chart = null, countChart = null;

    // Upright, because a rotated axis title turns an arrow sideways.
    const baselinePlugin = {
      id: "baselineLine",
      afterDatasetsDraw(instance){
        const {ctx, chartArea, scales} = instance;
        ctx.save();
        ctx.fillStyle = resolved("--muted");
        ctx.font = "11px ui-monospace, SFMono-Regular, Menlo, monospace";
        ctx.textAlign = "left";
        ctx.fillText("\u2191 worse", chartArea.left + 8, chartArea.top + 14);
        ctx.fillText("\u2193 better", chartArea.left + 8, chartArea.bottom - 6);

        const y = scales.y.getPixelForValue(1);
        if(y > chartArea.top && y < chartArea.bottom){
          ctx.strokeStyle = resolved("--muted");
          ctx.lineWidth = 1.5;
          ctx.beginPath();
          ctx.moveTo(chartArea.left, y);
          ctx.lineTo(chartArea.right, y);
          ctx.stroke();
        }
        ctx.restore();
      }
    };

    // Drawn before the scales so the gridlines stay on top, and shared by both
    // charts so a release is one band running down the pair.
    const stripePlugin = {
      id: "stripes",
      beforeDraw(instance){
        const {ctx, chartArea, data} = instance;
        const count = data.labels.length;
        if(!count || !chartArea) return;

        const width = (chartArea.right - chartArea.left) / count;
        ctx.save();
        ctx.fillStyle = resolved("--band");
        for(let index = 0; index < count; index += 2){
          ctx.fillRect(chartArea.left + index * width, chartArea.top, width, chartArea.bottom - chartArea.top);
        }
        ctx.restore();
      }
    };

    function datasetsFor(drawn){
      const sets = [];
      drawn.forEach(series => {
        const colour = resolved(series.color.slice(4, -1));
        if(series.noise){
          const spread = (sign) => series.points.map(v => v == null ? null : v*(1 + sign*series.noise));
          sets.push({type: "line", isBand: true, data: spread(1), borderWidth: 0, pointRadius: 0,
            backgroundColor: withAlpha(colour, 0.12), fill: "+1", order: 3});
          sets.push({type: "line", isBand: true, data: spread(-1), borderWidth: 0, pointRadius: 0,
            fill: false, order: 3});
        }
        sets.push({
          type: "line",
          label: series.label,
          data: series.points,
          totals: series.totals,
          unit: series.unit,
          backgroundColor: colour,
          borderColor: colour,
          borderWidth: 2,
          pointRadius: 2.4,
          pointHoverRadius: 5,
          tension: 0,
          spanGaps: true,
          order: 1
        });
      });
      return sets;
    }

    // Every release measured, so the extent is the same whatever the range and
    // baseline are showing. A release missing a measurement is left out rather
    // than summed short, which would drag the low end down.
    function countExtent(ruby){
      const keys = shownKeys();
      const versions = HAS_WORKING_TREE ? RELEASES.concat(WORKING_TREE) : RELEASES;
      const totals = [];
      CONCS.forEach(concurrency => versions.forEach(version => {
        const found = keys.map(k => valueAt(ruby, concurrency, version, k, "count")).filter(n => n != null);
        if(found.length === keys.length) totals.push(found.reduce((a, b) => a + b, 0));
      }));
      return totals.length ? totals : [0, 1];
    }

    // Counted rather than sampled, so these are the objects themselves, and the
    // baseline the timings are measured against does not touch them.
    function countDatasets(drawn){
      return drawn.map(series => {
        const colour = resolved(series.color.slice(4, -1));
        return {
          type: "bar", label: series.label, data: series.totals, unit: "objects",
          backgroundColor: withAlpha(colour, 0.75), borderColor: colour, borderWidth: 0
        };
      });
    }

    // Both scales reserve the same width, or the two plots would not line up.
    const GUTTER = 78;
    const axisFont = {family: "ui-monospace, SFMono-Regular, Menlo, monospace", size: 11};

    function draw(){
      const ruby = rubyChoice.value;
      const drawn = CONCS.map(c => seriesFor(ruby, c, TIMING));
      const counted = CONCS.map(c => seriesFor(ruby, c, "count"));
      const versions = axisVersions();
      const flat = drawn.flatMap(s => s.points.filter(n => n != null)
        .flatMap(n => s.noise ? [n*(1+s.noise), n*(1-s.noise)] : [n]));
      let lo = Math.min(...flat, 1), hi = Math.max(...flat, 1);
      // A series thirty times the baseline flattens every other line against the
      // axis. Laddered like the linear branch, and symmetric as a ratio rather
      // than as a distance, so twice as slow and twice as fast are the same size.
      const logarithmic = hi/lo > 4;
      if(logarithmic){
        const reach = Math.max(hi, 1/lo);
        const FACTORS = [1.5, 2, 3, 5, 10];
        const factor = FACTORS.find(step => reach <= step * 0.95) || Math.ceil(reach * 1.05);
        lo = 1/factor; hi = factor;
      } else {
        // Snapped and symmetric about no change, so switching baseline re-zeroes
        // the lines without also resizing the axis under them.
        const reach = Math.max(Math.abs(hi - 1), Math.abs(1 - lo));
        const RUNGS = [0.05, 0.1, 0.15, 0.2, 0.3, 0.4, 0.6, 0.8, 1];
        const rung = RUNGS.find(step => reach <= step * 0.92) || Math.ceil(reach * 1.08 * 10) / 10;
        lo = 1 - rung; hi = 1 + rung;
      }

      const config = {
        data: {labels: versions, datasets: datasetsFor(drawn)},
        options: {
          responsive: true,
          maintainAspectRatio: false,
          animation: false,
          interaction: {mode: "nearest", intersect: true},
          scales: {
            x: {ticks: {display: false}, grid: {display: false}},
            y: {type: logarithmic ? "logarithmic" : "linear", min: lo, max: hi,
                afterFit(scale){ scale.width = GUTTER; },
                ticks: {color: resolved("--muted"), callback: value => asPercent(value), font: axisFont},
                grid: {color: resolved("--grid")}}
          },
          plugins: {
            legend: {display: false},
            tooltip: {
              filter: item => !item.dataset.isBand,
              callbacks: {
                title: items => items.length ? items[0].label : "",
                label(item){
                  const total = item.dataset.totals && item.dataset.totals[item.dataIndex];
                  const shown = total == null ? ""
                    : ` · ${item.dataset.unit === "objects" ? Math.round(total).toLocaleString() : total.toFixed(2)} ${item.dataset.unit}`;
                  return `${item.dataset.label}${shown} · ${asPercent(item.parsed.y)} against ${baseline().version}`;
                }
              }
            }
          }
        },
        plugins: [stripePlugin, baselinePlugin]
      };

      // Over every release rather than the visible window, so scrolling the range
      // or moving the baseline never rescales the bars underneath you.
      const everCounted = countExtent(ruby);
      const countLo = Math.min(...everCounted), countHi = Math.max(...everCounted);
      const countMargin = (countHi - countLo) * 0.18 || Math.max(countHi * 0.02, 1);

      const countConfig = {
        data: {labels: versions, datasets: countDatasets(counted)},
        options: {
          responsive: true,
          maintainAspectRatio: false,
          animation: false,
          interaction: {mode: "nearest", intersect: true},
          scales: {
            x: {ticks: {maxRotation: 52, minRotation: 52, autoSkip: true, color: resolved("--muted"),
                  font: {family: "ui-monospace, SFMono-Regular, Menlo, monospace", size: 10},
                  callback(index){ return String(this.getLabelForValue(index)).replace(/^v/, ""); }},
                grid: {display: false}},
            y: {min: countLo - countMargin, max: countHi + countMargin,
                afterFit(scale){ scale.width = GUTTER; },
                ticks: {color: resolved("--muted"), maxTicksLimit: 4,
                  callback: value => Math.round(value).toLocaleString(), font: axisFont},
                grid: {color: resolved("--grid")}}
          },
          plugins: {
            legend: {display: false},
            tooltip: {callbacks: {
              title: items => items.length ? items[0].label : "",
              label(item){
                const previous = item.dataset.data[item.dataIndex - 1];
                const moved = previous == null ? null : Math.round(item.parsed.y - previous);
                const since = moved == null ? ""
                  : ` · ${moved > 0 ? "+" : moved < 0 ? "\\u2212" : "\\u00b1"}${Math.abs(moved).toLocaleString()} since ${versions[item.dataIndex - 1]}`;
                return `${item.dataset.label} · ${Math.round(item.parsed.y).toLocaleString()} objects${since}`;
              }
            }}
          }
        },
        plugins: [stripePlugin]
      };

      if(chart) chart.destroy();
      if(countChart) countChart.destroy();
      chart = new Chart(document.getElementById("chart"), config);
      countChart = new Chart(document.getElementById("countchart"), countConfig);
      document.querySelector(".cardtitle").textContent =
        `ruby ${ruby}, against ${baseline().version}${logarithmic ? ", log scale" : ""}`;

      // Two keys rather than four labels, since colour and shape each carry one thing.
      const swatch = kind => kind === "bar"
        ? `<svg class="sw" viewBox="0 0 16 10"><rect x="2" y="1" width="5" height="8" fill="var(--muted)"/>` +
          `<rect x="9" y="3" width="5" height="6" fill="var(--muted)"/></svg>`
        : `<svg class="sw" viewBox="0 0 16 10"><path d="M1 7 L6 3 L10 6 L15 2" fill="none" ` +
          `stroke="var(--muted)" stroke-width="1.6"/></svg>`;
      document.getElementById("legend").innerHTML =
        CONCS.map(c => `<span class="key"><span class="sw" style="background:${CONC_COLOR[c]}"></span>concurrency ${c}</span>`).join("") +
        `<span class="key">${swatch("line")}upper: ${SERIES_LABEL[TIMING]}, against ${baseline().version}</span>` +
        `<span class="key">${swatch("bar")}lower: allocations, objects</span>`;

      document.getElementById("sub").textContent =
        `${shownKeys().length} measurements · ${versions.length} releases · ` +
        `each line a move from ruby ${baseline().ruby} at ${baseline().version}` +
        `, both at concurrency ${CONCS[0]}` +
        ` · shaded band is ±${(noiseFloor()*100).toFixed(1)}%, what repeating the probe is worth` +
        (ELSEWHERE.length ? ` · milliseconds only from ${HERE}, since ${ELSEWHERE.join(" and ")} cannot be compared to it` : "") +
        (HAS_WORKING_TREE && !ROWS.some(r => r.version === WORKING_TREE && r.ruby === ruby)
          ? ` · the working tree was measured on ruby ${MEASURED.ruby}, not ${ruby}` : "");

      table(CONCS.map(c => seriesFor(ruby, c, metric.value)), asPercent);
      document.documentElement.style.setProperty("--barh",
        document.querySelector(".bar").offsetHeight + "px");
    }


    // Allocations are deterministic, so half a percent is real. A timing that close is the machine.
    function threshold(series){ return metric.value === "count" ? 0.005 : Math.max(0.005, series.noise); }

    // Release order is a sort like any other rather than the unsorted state.
    let rows = [], sortBy = "release", ascending = true;

    // A column of steps makes you add them up to see where a release landed.
    let firstVersion = null;

    function table(drawn, fmt){
      rows = [];
      firstVersion = null;
      // Every point is already a ratio to the baseline, so the column is the point itself.
      firstVersion = baseline().version;
      // Allocations are counted, not sampled, so a reader wants the objects.
      const counted = metric.value === "count";
      drawn.forEach(series => {
        let previous = null, previousTotal = null;
        series.versions.forEach((v, idx) => {
          const point = series.points[idx];
          if(point == null) return;
          const total = series.totals[idx];
          const change = previous == null ? null : (point-previous)/previous;
          rows.push({release: v, order: idx, concurrency: series.concurrency,
            ruby: series.ruby, value: point, change, counted,
            text: counted ? Math.round(total).toLocaleString() : fmt(point),
            since: point - 1,
            changeObjects: previousTotal == null ? null : Math.round(total - previousTotal),
            sinceObjects: Math.round(total - series.baseTotal),
            moved: change != null && Math.abs(change) >= threshold(series)});
          previous = point; previousTotal = total;
        });
      });
      document.getElementById("sincehead").firstChild.textContent =
        firstVersion ? `since ${firstVersion}` : "since";
      render();
    }

    function render(){
      const dir = ascending ? 1 : -1;
      const key = r => sortBy === "release" ? r.order
        : sortBy === "change" ? (r.change ?? 0)
        : sortBy === "since" ? (r.since ?? 0)
        : sortBy === "value" ? r.value
        : r[sortBy];
      // The working tree is the row you came for, so the filter never takes it.
      const shown = tablerows.value === "all" ? rows : rows.filter(r => r.moved || r.release === WORKING_TREE);
      const sorted = [...shown].sort((a, b) => {
        const x = key(a), y = key(b);
        if(x === y) return a.order - b.order;
        return (typeof x === "string" ? x.localeCompare(y) : x - y) * dir;
      });
      document.querySelector("#tbl tbody").innerHTML = sorted.map(r => {
        const cls = !r.moved ? "" : r.change > 0 ? "up" : "down";
        const signed = (n, suffix) => (n > 0 ? "+" : n < 0 ? "\u2212" : "") + Math.abs(n).toLocaleString() + suffix;
        const pct = r.change == null ? "\u2014"
          : r.counted ? signed(r.changeObjects, "")
          : signed(Number((r.change*100).toFixed(1)), "%");
        const since = r.since == null ? "\u2014"
          : r.counted ? signed(r.sinceObjects, "")
          : signed(Number((r.since*100).toFixed(1)), "%");
        const sinceClass = Math.abs(r.since) < 0.005 ? "" : r.since > 0 ? "up" : "down";
        return `<tr><td>${r.release}</td><td>${r.concurrency}</td><td>${r.ruby}</td><td>${r.text}</td>` +
          `<td class="${cls}">${pct}</td><td class="${sinceClass}">${since}</td></tr>`;
      }).join("") || `<tr><td colspan='6'>${metric.value === "count" ? "no changes above 0.5%" : "no changes above the measurement noise"}</td></tr>`;

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

    view.onchange = draw; metric.onchange = draw; prereleases.onchange = draw;
    baselineChoice.onchange = draw; rubyChoice.onchange = draw;
    rangeChoice.onchange = draw; draw();
    </script></body></html>
  HTML
end

if $PROGRAM_NAME == __FILE__
  path = ChartPage.run(open: !ARGV.include?("--no-open"), current: !ARGV.include?("--no-current"))
  puts "wrote #{path}"
end
