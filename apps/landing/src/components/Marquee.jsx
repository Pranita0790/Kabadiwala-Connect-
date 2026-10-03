import { marqueeItems } from "../data/content";

export default function Marquee() {
  const items = [...marqueeItems, ...marqueeItems];

  return (
    <div className="mq" aria-hidden="true">
      <div>
        {items.map((item, index) => (
          <span key={`${item.text}-${index}`} className={item.serif ? "serif" : undefined}>
            {item.text}
          </span>
        ))}
      </div>
    </div>
  );
}
