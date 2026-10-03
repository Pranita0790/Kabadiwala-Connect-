import { languages } from "../data/content";

export default function Navbar({ language, onLanguageChange }) {
  return (
    <nav>
      <b>Kabadiwala Connect</b>
      <div className="langs" role="group" aria-label="Language">
        {languages.map((lang) => (
          <button
            key={lang.code}
            type="button"
            data-l={lang.code}
            aria-pressed={language === lang.code}
            onClick={() => onLanguageChange(lang.code)}
          >
            {lang.label}
          </button>
        ))}
      </div>
    </nav>
  );
}
