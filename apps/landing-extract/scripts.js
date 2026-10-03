
const T={en:document.getElementById('sub').textContent,
hi:'ई-कचरा इकट्ठा करने वालों के लिए सही दाम, भरोसेमंद रीसाइक्लर और हर हैंडओवर का पक्का रिकॉर्ड।',
mr:'ई-कचरा गोळा करणाऱ्यांसाठी योग्य भाव, विश्वासू रिसायकलर आणि प्रत्येक हस्तांतराची पक्की नोंद.'};
document.querySelectorAll('.langs button').forEach(b=>b.onclick=()=>{
  document.querySelectorAll('.langs button').forEach(x=>x.setAttribute('aria-pressed',x===b));
  document.documentElement.lang=b.dataset.l;document.getElementById('sub').textContent=T[b.dataset.l];});
['gaps','impact'].forEach(id=>{const t=document.getElementById(id),bs=[...t.children],ps=[];
  let n=t.nextElementSibling;while(n&&n.classList.contains('tabpanel')){ps.push(n);n=n.nextElementSibling;}
  bs.forEach((b,i)=>b.onclick=()=>{bs.forEach((x,j)=>{x.setAttribute('aria-selected',i===j);ps[j].hidden=i!==j;});});});
if(!matchMedia('(prefers-reduced-motion:reduce)').matches){
  const chips=[...document.querySelectorAll('.chip')];
  addEventListener('pointermove',e=>{const x=e.clientX/innerWidth-.5,y=e.clientY/innerHeight-.5;
    chips.forEach(c=>{const d=+c.dataset.d;c.style.transform=`translate(${x*d*2}px,${y*d*2}px) rotate(${x*d/2}deg)`;});});
  const io=new IntersectionObserver(es=>es.forEach(e=>{if(!e.isIntersecting)return;io.unobserve(e.target);
    const el=e.target,end=+el.dataset.n,s=el.dataset.s;let t0;
    const f=t=>{t0=t0||t;const p=Math.min((t-t0)/1200,1);el.textContent=Math.round(end*p)+s;if(p<1)requestAnimationFrame(f);};requestAnimationFrame(f);}),{threshold:.6});
  document.querySelectorAll('[data-n]').forEach(el=>io.observe(el));}
