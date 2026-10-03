export default function PhoneMockup({ image, alt, caption }) {
  return (
    <div className="phwrap">
      <div className="ph">
        <img src={image} alt={alt} />
      </div>
      <p className="cap">{caption}</p>
    </div>
  );
}
