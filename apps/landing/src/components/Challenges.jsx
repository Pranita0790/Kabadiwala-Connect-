import { Fragment, useState } from "react";
import { challenges, impactTabs } from "../data/content";

export default function Challenges() {
  const [activeTab, setActiveTab] = useState(0);

  return (
    <section>
      <div className="wrap">
        <h2>
          Who<span className="serif"> benefits</span>
        </h2>
        <div
          className="tabs"
          role="tablist"
          id="impact"
          aria-label="Who benefits"
        >
          {impactTabs.map((tab, index) => (
            <button
              key={tab.label}
              type="button"
              role="tab"
              id={`impact-tab-${index}`}
              aria-controls={`impact-panel-${index}`}
              aria-selected={activeTab === index}
              onClick={() => setActiveTab(index)}
            >
              {tab.label}
            </button>
          ))}
        </div>
        {impactTabs.map((tab, index) => (
          <div
            key={tab.label}
            className="tabpanel big"
            role="tabpanel"
            id={`impact-panel-${index}`}
            aria-labelledby={`impact-tab-${index}`}
            hidden={activeTab !== index}
          >
            {tab.content}
          </div>
        ))}
        <div className="ch">
          {challenges.map((item) => (
            <Fragment key={item.a}>
              <div className="a">{item.a}</div>
              <div className="b">{item.b}</div>
            </Fragment>
          ))}
        </div>
      </div>
    </section>
  );
}
