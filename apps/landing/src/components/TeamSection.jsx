import { teamMembers, whoCopy } from "../data/content";

export default function TeamSection() {
  return (
    <section id="who">
      <div className="wrap two">
        <div>
          <h2>
            Who<span className="serif"> we are</span>
          </h2>
          <div className="team">
            {teamMembers.map((name) => (
              <div key={name}>
                {name}
                <em className="serif">team</em>
              </div>
            ))}
          </div>
        </div>
        <div>
          {whoCopy.map((paragraph, index) => (
            <span key={paragraph}>
              <p className="big">{paragraph}</p>
              {index < whoCopy.length - 1 ? <br /> : null}
            </span>
          ))}
        </div>
      </div>
    </section>
  );
}
