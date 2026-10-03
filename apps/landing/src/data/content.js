export const languages = [
  { code: "en", label: "English" },
  { code: "hi", label: "हिन्दी" },
  { code: "mr", label: "मराठी" },
];

export const heroSubtitles = {
  en: "A vernacular, offline-first platform that helps informal e-waste collectors identify material, discover fair value, meet authorized recyclers and keep proof of every handover.",
  hi: "ई-कचरा इकट्ठा करने वालों के लिए सही दाम, भरोसेमंद रीसाइक्लर और हर हैंडओवर का पक्का रिकॉर्ड।",
  mr: "ई-कचरा गोळा करणाऱ्यांसाठी योग्य भाव, विश्वासू रिसायकलर आणि प्रत्येक हस्तांतराची पक्की नोंद.",
};

export const heroMeta = [
  "Team Gurlypops",
  "CSI Hackathon, Round 1",
  "Domain: AI & ML",
];

export const floatingChips = [
  { label: "Old phone", style: { top: "20%", right: "10%" }, d: 30 },
  { label: "Laptop", style: { top: "38%", right: "26%" }, d: -20 },
  { label: "Circuit board", style: { top: "55%", right: "8%" }, d: 45 },
  { label: "Charger", style: { top: "70%", right: "30%" }, d: -40 },
  { label: "Battery", style: { top: "28%", right: "42%" }, d: 25 },
];

export const marqueeItems = [
  { text: "Empowering people", serif: false },
  { text: "Enabling circularity", serif: true },
  { text: "A cleaner India for all", serif: false },
  { text: "Empowering people", serif: true },
  { text: "Enabling circularity", serif: false },
  { text: "A cleaner India for all", serif: true },
];

export const teamMembers = [
  "Shalaka Sonawane",
  "Pranita Shinde",
  "Anurag Shukla",
  "Harsh Alker",
];

export const whoCopy = [
  "We are Gurlypops, a four-person team in the AI & ML domain of the CSI Hackathon.",
  "We chose a problem we could see clearly: e-waste leaves homes through informal collectors, and the trail goes dark before it reaches a verified recycler.",
  "Kabadiwala Connect is our answer. It strengthens the network that already exists instead of replacing it.",
];

export const problemFlow = [
  { text: "Household or source", gap: false },
  { text: "Informal collector", gap: false },
  { text: "Local buyer or middleman", gap: false },
  {
    text: "Digital gap: price, authorization, traceability, records",
    gap: true,
  },
];

export const stats = [
  {
    value: "78%",
    label: "of e-waste processing is informal (NITI Aayog 2026)",
    n: 78,
    s: "%",
  },
  {
    value: "10–20%",
    label: "estimated informal material recovery",
  },
  {
    value: "95–97%",
    label: "estimated formal material recovery",
  },
  {
    value: "14 MT",
    label: "projected Indian e-waste by 2030",
    n: 14,
    s: " MT",
  },
];

export const gapTabs = [
  {
    label: "Price",
    content:
      "Collectors may lack transparent, reliable valuation. Without it, they sell blind.",
  },
  {
    label: "Routing",
    content:
      "Suitable authorized recyclers are hard to discover efficiently, so lots end up with whoever is nearest.",
  },
  {
    label: "Traceability",
    content:
      "Lot, payment and handover records stay fragmented, so nobody can prove where material went.",
  },
];

export const gapFootnote =
  "Today MetalMandi helps with price discovery, The Kabadiwala with collection, Karo Sambhav with EPR and formalization, and traditional networks with last-mile reach. The connection from field collector to authorized recycler is still open.";

export const workflowSteps = [
  {
    number: "1",
    title: "Collect e-waste",
    description:
      "The collector gathers e-waste from households, markets or institutions.",
    color: "var(--lime)",
    tag: null,
  },
  {
    number: "2",
    title: "Identify and weigh",
    description:
      "AI-assisted material categorization plus weight entry. Point the camera, confirm the weight.",
    color: "var(--lilac)",
    tag: "AI & ML",
  },
  {
    number: "3",
    title: "Get a fair price",
    description: "A local market-based price range, shown openly before any deal.",
    color: "var(--sky)",
    tag: null,
  },
  {
    number: "4",
    title: "Match a recycler",
    description: "Find nearby verified, authorized recyclers on a map.",
    color: "var(--orange)",
    tag: null,
  },
  {
    number: "5",
    title: "Handover and trace",
    description:
      "A digital handover record, payment confirmation and a material passport that follows the lot.",
    color: "#fff",
    tag: "Verifiable record",
  },
];

export const phoneScreens = [
  {
    image: "phone-screen-1",
    alt: "Lot Details screen showing a motherboard weighing 5 kg with an estimated value of 1,400 to 2,100 rupees",
    caption: "Lot details and fair value",
  },
  {
    image: "phone-screen-2",
    alt: "Recycler Matching screen listing nearby authorized e-waste recyclers with distance, price per kg and rating",
    caption: "Recycler matching",
  },
];

export const featureRows = [
  [
    {
      title: "Works with existing networks",
      description:
        "Strengthens informal collector networks instead of replacing them.",
    },
    {
      title: "Fair-price transparency",
      description: "Market-based price guidance for better earnings.",
    },
    {
      title: "Digital material passport",
      description:
        "End-to-end traceability from collector to authorized recycler.",
    },
    {
      title: "Inclusive and accessible",
      description: "Multilingual, low-literacy friendly, with offline support.",
    },
  ],
  [
    {
      title: "Fair Price Engine",
      description: "Transparent price ranges for collected e-waste.",
    },
    {
      title: "Smart Recycler Matching",
      description: "Connects collectors with nearby verified recyclers.",
    },
    {
      title: "AI Material Identification",
      description: "Helps identify and categorize e-waste.",
    },
    {
      title: "Earnings & Handover Ledger",
      description:
        "Simple records for payments, quantities and transactions.",
    },
  ],
];

export const techStack = [
  "React.js",
  "Node.js",
  "PostgreSQL",
  "Vercel",
  "Render / AWS",
  "Maps API",
  "Email / SMS",
  "Price data API",
  "Git & GitHub",
  "Postman",
];

export const architectureFlow = [
  "Collector / Recycler / Admin",
  "React app",
  "Node.js APIs",
  "PostgreSQL",
];

export const impactTabs = [
  {
    label: "Collectors",
    content:
      "Fair and transparent pricing, better income opportunities, digital records and recognition.",
  },
  {
    label: "Recyclers",
    content:
      "Easier access to verified collection lots, more consistent supply, stronger compliance and traceability.",
  },
  {
    label: "Traceability",
    content:
      "End-to-end digital material tracking, verified handover records, less leakage into informal, untracked channels.",
  },
  {
    label: "Environment",
    content:
      "More e-waste in formal recycling, fewer environmental hazards, a cleaner, circular, healthier India.",
  },
];

export const challenges = [
  {
    a: "Low digital literacy",
    b: "Simple Hindi/Marathi UI, icon-based navigation, on-ground onboarding and training.",
  },
  {
    a: "Trust and adoption",
    b: "Transparent pricing, verified recycler listings, awareness campaigns with local bodies and NGOs.",
  },
  {
    a: "Data authenticity and misuse",
    b: "User verification, secure cloud infrastructure, role-based access and audit logs.",
  },
];

export const roadmap = [
  {
    title: "Pilot",
    description: "Test and refine with a small set of collectors and recyclers.",
  },
  {
    title: "City",
    description: "Expand to more wards and recyclers within the city.",
  },
  {
    title: "State",
    description:
      "Integrate with state pollution control boards and e-waste networks.",
  },
  {
    title: "National",
    description:
      "Scale across India with AI, analytics and policy integration for data-driven decisions.",
  },
];
