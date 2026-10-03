import { workflowSteps } from "../data/content";

export default function Workflow() {
  return (
    <section id="workflow" style={{ background: "var(--ink)", color: "var(--bg)" }}>
      <div className="wrap">
        <h2>
          Our workflow,<span className="serif"> collection to recycling</span>
        </h2>
        <div className="steps">
          {workflowSteps.map((step, index) => (
            <div
              key={step.number}
              className="step"
              style={{ "--i": index, background: step.color }}
            >
              <div className="n serif">{step.number}</div>
              <div>
                <h3>{step.title}</h3>
                <p>{step.description}</p>
                {step.tag ? <span className="tag">{step.tag}</span> : null}
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
