import { useEffect, useRef } from "react";
import { floatingChips, heroMeta, heroSubtitles } from "../data/content";

export default function Hero({ language }) {
  const chipsRef = useRef(null);

  useEffect(() => {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      return undefined;
    }

    const chips = chipsRef.current
      ? [...chipsRef.current.querySelectorAll(".chip")]
      : [];

    const onMove = (e) => {
      const x = e.clientX / window.innerWidth - 0.5;
      const y = e.clientY / window.innerHeight - 0.5;
      chips.forEach((c) => {
        const d = Number(c.dataset.d);
        c.style.transform = `translate(${x * d * 2}px,${y * d * 2}px) rotate(${x * d * 0.5}deg)`;
      });
    };

    window.addEventListener("pointermove", onMove);
    return () => window.removeEventListener("pointermove", onMove);
  }, []);

  return (
    <header className="hero">
      <div className="chips" aria-hidden="true" ref={chipsRef}>
        {floatingChips.map((chip) => (
          <span
            key={chip.label}
            className="chip"
            style={chip.style}
            data-d={chip.d}
          >
            {chip.label}
          </span>
        ))}
      </div>
      <div className="wrap" style={{ position: "relative" }}>
        <h1>
          Fair price
          <span className="serif">for every kabadiwala.</span>
        </h1>
        <p className="sub" id="sub">
          {heroSubtitles[language] || heroSubtitles.en}
        </p>
        <a className="cta" href="#workflow">
          See how it works <i />
        </a>
        <div className="meta">
          {heroMeta.map((item) => (
            <span key={item}>{item}</span>
          ))}
        </div>
      </div>
    </header>
  );
}
