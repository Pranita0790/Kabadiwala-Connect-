const fs = require("fs");
const path = require("path");

const htmlPath = path.join(__dirname, "_landing_source.html");
const outDir = path.join(__dirname, "landing-extract");
fs.mkdirSync(outDir, { recursive: true });

const html = fs.readFileSync(htmlPath, "utf8");
const style = (html.match(/<style>([\s\S]*?)<\/style>/) || [])[1] || "";
const body = (html.match(/<body>([\s\S]*?)<\/body>/) || [])[1] || "";
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);

fs.writeFileSync(path.join(outDir, "style.css"), style);
fs.writeFileSync(path.join(outDir, "body.html"), body);
fs.writeFileSync(path.join(outDir, "scripts.js"), scripts.join("\n\n/* ---- */\n\n"));

const assetsDir = path.join(outDir, "assets");
fs.mkdirSync(assetsDir, { recursive: true });
const imgRe = /src="(data:image\/([a-zA-Z0-9+]+);base64,([^"]+))"/g;
let i = 0;
let m;
const mapped = [];
while ((m = imgRe.exec(html))) {
  i += 1;
  const ext = m[2] === "jpeg" ? "jpg" : m[2];
  const name = `phone-screen-${i}.${ext}`;
  fs.writeFileSync(path.join(assetsDir, name), Buffer.from(m[3], "base64"));
  mapped.push(name);
}

const queue = [...mapped];
const bodyClean = body.replace(
  /src="data:image\/[a-zA-Z0-9+]+;base64,[^"]+"/g,
  () => {
    const name = queue.shift();
    return `src="./assets/${name}"`;
  }
);
fs.writeFileSync(path.join(outDir, "body-clean.html"), bodyClean);

console.log(
  JSON.stringify(
    {
      styleLen: style.length,
      bodyLen: body.length,
      scripts: scripts.length,
      images: i,
      title: (html.match(/<title>([^<]*)<\/title>/) || [])[1],
    },
    null,
    2
  )
);
