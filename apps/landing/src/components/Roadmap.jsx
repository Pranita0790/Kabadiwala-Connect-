import { roadmap } from "../data/content";

export default function Roadmap() {
  return (
    <section style={{ paddingTop: 0 }}>
      <div className="wrap">
        <h2>
          From a pilot<span className="serif"> to a nation</span>
        </h2>
        <div className="road">
          {roadmap.map((item) => (
            <div key={item.title}>
              <span className="serif">{item.title}</span>
              <p>{item.description}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
