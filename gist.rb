
require 'openssl'
require 'midori'
require 'json'

def json x
  x = JSON.generate x unless String === x
  Midori::Response.new(status: 200,
                       header: { 'Content-Type': 'application/json' },
                       body: x)
end

class AppRoute < Midori::API
  capture Errno::ENOENT do
    Midori::Response.new status: 404, body: 'Not found'
  end

  get '/' do
    <<~HTML
      <!doctype HTML>
      <title>Gists</title>
      <style>
        body { padding: 20px 40px 40px; }
        details > details { padding-left: 1em; }
        summary { font-family: monospace; cursor: pointer; }
        pre { margin: 0; padding: 8px; background-color: rgba(0,0,120,.1);
              white-space: pre-wrap; }</style>
      <body>
        <h2>Gists</h2>
      <script>
        (async () => {
          const nop = () => {};
          const toJson = r => r.json();
          const toText = r => r.text();
          const tap = o => f => (f(o), o);
          const elt = (t, ...a) =>
            tap(document.createElement(t))(e => e.append(...a));
          const gists = await fetch("gists.json").then(toJson);
          for (const { url, description } of gists.reverse()) {
            const a = tap(elt('a', url.substring(24, 32)))(a => a.href = url);
            const s = elt('summary', `[`, a, `] ${description}`);
            const e = elt('details', s);
            e.onclick = async () => {
              const d = url.substring(24);
              const f = await fetch(d).then(toJson);
              for (const g of f) {
                const t = elt('summary', g);
                const h = elt('details', t);
                t.onclick = async () => {
                  const r = await fetch(`${d}/${g}`).then(toText);
                  h.append(elt('pre', elt('code', r)));
                  t.onclick = nop;
                };
                e.append(h);
              }
              e.onclick = nop;
            };
            document.body.append(e);
          }
        })();
      </script>
    HTML
  end

  get '/gists.json' do
    json File.read('gists.json')
  end

  get '*' do
    path = File.join '.', request.params['splat'][0]
    if File.directory? path
      json Dir.entries(path).reject { |e| e.start_with? ?. }
    else
      File.read path
    end
  end
end

begin
  Midori::Runner.new(AppRoute).start
rescue Interrupt
  puts '^C'
end
