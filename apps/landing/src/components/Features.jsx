import { featureRows } from "../data/content";

export default function Features() {
  return (
    <section>
      <div className="wrap">
        <h2>
          What makes it<span className="serif"> different</span>
        </h2>
        {featureRows.map((row, rowIndex) => (
          <div className="feat" key={`feat-row-${rowIndex}`}>
            {row.map((feature) => (
              <div key={feature.title}>
                <h3>{feature.title}</h3>
                <p>{feature.description}</p>
              </div>
            ))}
          </div>
        ))}
      </div>
    </section>
  );
}
