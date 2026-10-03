import { useEffect, useState } from "react";
import Architecture from "./components/Architecture";
import Challenges from "./components/Challenges";
import Features from "./components/Features";
import Footer from "./components/Footer";
import GapTabs from "./components/GapTabs";
import Hero from "./components/Hero";
import Marquee from "./components/Marquee";
import Navbar from "./components/Navbar";
import PhoneShowcase from "./components/PhoneShowcase";
import ProblemSection from "./components/ProblemSection";
import Roadmap from "./components/Roadmap";
import TeamSection from "./components/TeamSection";
import Workflow from "./components/Workflow";

export default function App() {
  const [language, setLanguage] = useState("en");

  useEffect(() => {
    document.documentElement.lang = language;
  }, [language]);

  return (
    <>
      <Navbar language={language} onLanguageChange={setLanguage} />
      <Hero language={language} />
      <Marquee />
      <TeamSection />
      <ProblemSection />
      <GapTabs />
      <Workflow />
      <PhoneShowcase />
      <Features />
      <Architecture />
      <Challenges />
      <Roadmap />
      <Footer />
    </>
  );
}
