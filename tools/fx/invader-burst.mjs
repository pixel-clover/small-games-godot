export const meta = {
  name: "Invader burst",
  desc: "A white impact core opens into a thin shock ring and short sparks that slow and fade.",
  tags: ["explosion", "impact", "one-shot"],
  size: [48, 48],
  origin: [24, 24],
  duration: 0.3,
  fps: 30,
  loop: false,
  bg: "black",
  options: { palette: ["#333333", "#888888", "#cccccc", "#ffffff"], seed: 7 },
};

export function draw(p, t, o) {
  if (t < 0 || t >= meta.duration) return;
  const u = t / meta.duration, fade = 1 - u;
  const color = (hex) => {
    const rgb = parseInt(hex.slice(1), 16);
    return 0xff000000 | ((rgb & 255) << 16) | (rgb & 0xff00) | (rgb >>> 16);
  };
  const bright = color(o.palette[3]), mid = color(o.palette[2]);
  if (t < 0.067) {
    const r = 4 * (1 - t / 0.067);
    p.circle(0, 0, r, bright);
    p.line(-r * 2, 0, r * 2, 0, bright);
    p.line(0, -r * 2, 0, r * 2, bright);
  }
  const radius = 3 + 13 * (1 - Math.pow(fade, 3));
  if (t < 0.18) p.ring(0, 0, radius, 1, mid, Math.pow(1 - t / 0.18, 2));
  p.glow(0, 0, 17, mid, 0.25 * fade * fade);
  for (let i = 0; i < 10; i++) {
    const a = i * Math.PI * 2 / 10 + Math.sin(i * 13 + o.seed) * 0.16;
    const distance = 3 + (11 + (i % 3) * 3) * (1 - fade * fade);
    const length = 1 + 4 * fade * fade;
    const x = Math.cos(a), y = Math.sin(a);
    const intensity = Math.max(0, 1 - u / (0.78 + (i % 3) * 0.1));
    p.line(x * distance, y * distance, x * (distance - length), y * (distance - length), bright, intensity);
  }
}
