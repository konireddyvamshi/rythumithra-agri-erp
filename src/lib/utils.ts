export const uid=(p:string)=>`${p}_${crypto.randomUUID()}`
export const now=()=>new Date().toISOString()
export const money=(v:number)=>new Intl.NumberFormat('en-IN',{style:'currency',currency:'INR',maximumFractionDigits:2}).format(v||0)
export const num=(v:string|number|undefined)=>Number(v||0)
export const today=()=>new Date().toISOString().slice(0,10)
export const round2=(n:number)=>Math.round((n+Number.EPSILON)*100)/100
export const daysUntil=(date?:string)=>date?Math.ceil((new Date(`${date}T00:00:00`).getTime()-new Date().setHours(0,0,0,0))/86400000):Infinity
export const taxSplit=(rate:number,intra:boolean,taxable:number)=>rate<=0?{cgst:0,sgst:0,igst:0}:intra?{cgst:round2(taxable*rate/200),sgst:round2(taxable*rate/200),igst:0}:{cgst:0,sgst:0,igst:round2(taxable*rate/100)}
export const formatDate=(v?:string)=>v?new Date(`${v}T00:00:00`).toLocaleDateString('en-IN'):'-'
export const amountWords=(n:number)=>{const ones=['','One','Two','Three','Four','Five','Six','Seven','Eight','Nine','Ten','Eleven','Twelve','Thirteen','Fourteen','Fifteen','Sixteen','Seventeen','Eighteen','Nineteen'],tens=['','','Twenty','Thirty','Forty','Fifty','Sixty','Seventy','Eighty','Ninety'];const under100=(x:number)=>x<20?ones[x]:tens[Math.floor(x/10)]+(x%10?' '+ones[x%10]:'');const under1000=(x:number)=>x>=100?ones[Math.floor(x/100)]+' Hundred'+(x%100?' '+under100(x%100):''):under100(x);let r=Math.floor(n),p=Math.round((n-r)*100);let s='';if(r>=10000000){s+=under1000(Math.floor(r/10000000))+' Crore ';r%=10000000}if(r>=100000){s+=under1000(Math.floor(r/100000))+' Lakh ';r%=100000}if(r>=1000){s+=under1000(Math.floor(r/1000))+' Thousand ';r%=1000}if(r)s+=under1000(r);s=(s.trim()||'Zero')+' Rupees';if(p)s+=' and '+under100(p)+' Paisa';return s+' Only'}
