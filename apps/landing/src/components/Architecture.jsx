import { Fragment } from "react";
import { architectureFlow, techStack } from "../data/content";

export default function Architecture() {
  return (
    <section style={{ background: "var(--sky)" }} className="pan">
      <div className="wrap two">
        <div>
          <h2>
            How we<span className="serif"> build it</span>
          </h2>
          <div className="stack">
            {techStack.map((item) => (
              <span key={item}>{item}</span>
            ))}
          </div>
        </div>
        <div>
          <p className="big">
            Plan and design, develop, test, deploy, iterate. Frontend, backend
            and database modules are built iteratively and tested with real-world
            scenarios.
          </p>
          <div className="arch">
            {architectureFlow.map((node, index) => (
              <Fragment key={node}>
                <span>{node}</span>
                {index < architectureFlow.length - 1 ? <i>→</i> : null}
              </Fragment>
            ))}
          </div>
          <p style={{ marginTop: 28 }}>
            <b>Prototype status:</b> core features work (registration, material
            listing, recycler matching, digital records) and are being tested
            with sample users for usability and feedback.
          </p>
        </div>
      </div>
    </section>
  );
}
