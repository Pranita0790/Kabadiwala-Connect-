import { useState } from "react";
import { gapFootnote, gapTabs } from "../data/content";

export default function GapTabs() {
  const [activeTab, setActiveTab] = useState(0);

  return (
    <section>
      <div className="wrap">
        <h2>
          Three gaps,<span className="serif"> one platform</span>
        </h2>
        <div className="tabs" role="tablist" id="gaps" aria-label="Platform gaps">
          {gapTabs.map((tab, index) => (
            <button
              key={tab.label}
              type="button"
              role="tab"
              id={`gap-tab-${index}`}
              aria-controls={`gap-panel-${index}`}
              aria-selected={activeTab === index}
              onClick={() => setActiveTab(index)}
            >
              {tab.label}
            </button>
          ))}
        </div>
        {gapTabs.map((tab, index) => (
          <div
            key={tab.label}
            className="tabpanel big"
            role="tabpanel"
            id={`gap-panel-${index}`}
            aria-labelledby={`gap-tab-${index}`}
            hidden={activeTab !== index}
          >
            {tab.content}
          </div>
        ))}
        <p style={{ marginTop: 28, maxWidth: "60ch" }}>{gapFootnote}</p>
      </div>
    </section>
  );
}
