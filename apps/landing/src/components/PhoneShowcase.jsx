import phoneScreen1 from "../assets/phone-screen-1.jpg";
import phoneScreen2 from "../assets/phone-screen-2.jpg";
import { phoneScreens } from "../data/content";
import PhoneMockup from "./PhoneMockup";

const images = {
  "phone-screen-1": phoneScreen1,
  "phone-screen-2": phoneScreen2,
};

export default function PhoneShowcase() {
  return (
    <section id="app" style={{ background: "var(--lilac)" }} className="pan">
      <div className="wrap">
        <h2>
          See it<span className="serif"> on an iPhone</span>
        </h2>
        <p className="big" style={{ maxWidth: "34ch", marginTop: 20 }}>
          The working prototype: a collector logs a lot, sees a fair value, then
          finds an authorized recycler nearby.
        </p>
        <div className="phones">
          {phoneScreens.map((screen) => (
            <PhoneMockup
              key={screen.caption}
              image={images[screen.image]}
              alt={screen.alt}
              caption={screen.caption}
            />
          ))}
        </div>
      </div>
    </section>
  );
}
