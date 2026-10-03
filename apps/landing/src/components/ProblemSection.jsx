import { useEffect, useRef } from "react";
import { problemFlow, stats } from "../data/content";

export default function ProblemSection() {
  const statsRef = useRef(null);

  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      return undefined;
    }

    const root = statsRef.current;
    if (!root) return undefined;

    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          io.unobserve(entry.target);
          const el = entry.target;
          const end = Number(el.dataset.n);
          const s = el.dataset.s || "";
          let t0;
          const frame = (t) => {
            t0 = t0 || t;
            const p = Math.min((t - t0) / 1200, 1);
            el.textContent = `${Math.round(end * p)}${s}`;
            if (p < 1) requestAnimationFrame(frame);
          };
          requestAnimationFrame(frame);
        });
      },
      { threshold: 0.6 }
    );

    root.querySelectorAll("[data-n]").forEach((el) => io.observe(el));
    return () => io.disconnect();
  }, []);

  return (
    <section style={{ background: "var(--lilac)" }} className="pan" id="problem">
      <div className="wrap">
        <h2>
          The problem<span className="serif"> nobody sees</span>
        </h2>
        <div className="flow">
          {problemFlow.map((item) => (
            <div key={item.text} className={item.gap ? "gap" : undefined}>
              {item.text}
            </div>
          ))}
        </div>
        <p className="big">
          Material enters the informal network, but visibility is lost before
          verified formal recycling.
        </p>
        <div className="stats" ref={statsRef}>
          {stats.map((stat) => (
            <div key={stat.label}>
              <b data-n={stat.n} data-s={stat.s}>
                {stat.value}
              </b>
              <small>{stat.label}</small>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
