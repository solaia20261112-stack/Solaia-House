(()=>{var Ue=Object.create;var Lt=Object.defineProperty;var qe=Object.getOwnPropertyDescriptor;var De=Object.getOwnPropertyNames;var Fe=Object.getPrototypeOf,ke=Object.prototype.hasOwnProperty;var g=(n,t)=>()=>{try{return t||n((t={exports:{}}).exports,t),t.exports}catch(e){throw t=0,e}};var ze=(n,t,e,r)=>{if(t&&typeof t=="object"||typeof t=="function")for(let o of De(t))!ke.call(n,o)&&o!==e&&Lt(n,o,{get:()=>t[o],enumerable:!(r=qe(t,o))||r.enumerable});return n};var Ve=(n,t,e)=>(e=n!=null?Ue(Fe(n)):{},ze(t||!n||!n.__esModule?Lt(e,"default",{value:n,enumerable:!0}):e,n));var xt=g((Dn,_t)=>{_t.exports=function(){return typeof Promise=="function"&&Promise.prototype&&Promise.prototype.then}});var I=g(P=>{var st,He=[0,26,44,70,100,134,172,196,242,292,346,404,466,532,581,655,733,815,901,991,1085,1156,1258,1364,1474,1588,1706,1828,1921,2051,2185,2323,2465,2611,2761,2876,3034,3196,3362,3532,3706];P.getSymbolSize=function(t){if(!t)throw new Error('"version" cannot be null or undefined');if(t<1||t>40)throw new Error('"version" should be in range from 1 to 40');return t*4+17};P.getSymbolTotalCodewords=function(t){return He[t]};P.getBCHDigit=function(n){let t=0;for(;n!==0;)t++,n>>>=1;return t};P.setToSJISFunction=function(t){if(typeof t!="function")throw new Error('"toSJISFunc" is not a valid function.');st=t};P.isKanjiModeEnabled=function(){return typeof st<"u"};P.toSJIS=function(t){return st(t)}});var j=g(m=>{m.L={bit:1};m.M={bit:0};m.Q={bit:3};m.H={bit:2};function Ke(n){if(typeof n!="string")throw new Error("Param is not a string");switch(n.toLowerCase()){case"l":case"low":return m.L;case"m":case"medium":return m.M;case"q":case"quartile":return m.Q;case"h":case"high":return m.H;default:throw new Error("Unknown EC Level: "+n)}}m.isValid=function(t){return t&&typeof t.bit<"u"&&t.bit>=0&&t.bit<4};m.from=function(t,e){if(m.isValid(t))return t;try{return Ke(t)}catch{return e}}});var Dt=g((zn,qt)=>{function Ut(){this.buffer=[],this.length=0}Ut.prototype={get:function(n){let t=Math.floor(n/8);return(this.buffer[t]>>>7-n%8&1)===1},put:function(n,t){for(let e=0;e<t;e++)this.putBit((n>>>t-e-1&1)===1)},getLengthInBits:function(){return this.length},putBit:function(n){let t=Math.floor(this.length/8);this.buffer.length<=t&&this.buffer.push(0),n&&(this.buffer[t]|=128>>>this.length%8),this.length++}};qt.exports=Ut});var kt=g((Vn,Ft)=>{function k(n){if(!n||n<1)throw new Error("BitMatrix size must be defined and greater than 0");this.size=n,this.data=new Uint8Array(n*n),this.reservedBit=new Uint8Array(n*n)}k.prototype.set=function(n,t,e,r){let o=n*this.size+t;this.data[o]=e,r&&(this.reservedBit[o]=!0)};k.prototype.get=function(n,t){return this.data[n*this.size+t]};k.prototype.xor=function(n,t,e){this.data[n*this.size+t]^=e};k.prototype.isReserved=function(n,t){return this.reservedBit[n*this.size+t]};Ft.exports=k});var zt=g(G=>{var Je=I().getSymbolSize;G.getRowColCoords=function(t){if(t===1)return[];let e=Math.floor(t/7)+2,r=Je(t),o=r===145?26:Math.ceil((r-13)/(2*e-2))*2,i=[r-7];for(let s=1;s<e-1;s++)i[s]=i[s-1]-o;return i.push(6),i.reverse()};G.getPositions=function(t){let e=[],r=G.getRowColCoords(t),o=r.length;for(let i=0;i<o;i++)for(let s=0;s<o;s++)i===0&&s===0||i===0&&s===o-1||i===o-1&&s===0||e.push([r[i],r[s]]);return e}});var Kt=g(Ht=>{var Ye=I().getSymbolSize,Vt=7;Ht.getPositions=function(t){let e=Ye(t);return[[0,0],[e-Vt,0],[0,e-Vt]]}});var Jt=g(d=>{d.Patterns={PATTERN000:0,PATTERN001:1,PATTERN010:2,PATTERN011:3,PATTERN100:4,PATTERN101:5,PATTERN110:6,PATTERN111:7};var b={N1:3,N2:3,N3:40,N4:10};d.isValid=function(t){return t!=null&&t!==""&&!isNaN(t)&&t>=0&&t<=7};d.from=function(t){return d.isValid(t)?parseInt(t,10):void 0};d.getPenaltyN1=function(t){let e=t.size,r=0,o=0,i=0,s=null,u=null;for(let c=0;c<e;c++){o=i=0,s=u=null;for(let l=0;l<e;l++){let a=t.get(c,l);a===s?o++:(o>=5&&(r+=b.N1+(o-5)),s=a,o=1),a=t.get(l,c),a===u?i++:(i>=5&&(r+=b.N1+(i-5)),u=a,i=1)}o>=5&&(r+=b.N1+(o-5)),i>=5&&(r+=b.N1+(i-5))}return r};d.getPenaltyN2=function(t){let e=t.size,r=0;for(let o=0;o<e-1;o++)for(let i=0;i<e-1;i++){let s=t.get(o,i)+t.get(o,i+1)+t.get(o+1,i)+t.get(o+1,i+1);(s===4||s===0)&&r++}return r*b.N2};d.getPenaltyN3=function(t){let e=t.size,r=0,o=0,i=0;for(let s=0;s<e;s++){o=i=0;for(let u=0;u<e;u++)o=o<<1&2047|t.get(s,u),u>=10&&(o===1488||o===93)&&r++,i=i<<1&2047|t.get(u,s),u>=10&&(i===1488||i===93)&&r++}return r*b.N3};d.getPenaltyN4=function(t){let e=0,r=t.data.length;for(let i=0;i<r;i++)e+=t.data[i];return Math.abs(Math.ceil(e*100/r/5)-10)*b.N4};function Oe(n,t,e){switch(n){case d.Patterns.PATTERN000:return(t+e)%2===0;case d.Patterns.PATTERN001:return t%2===0;case d.Patterns.PATTERN010:return e%3===0;case d.Patterns.PATTERN011:return(t+e)%3===0;case d.Patterns.PATTERN100:return(Math.floor(t/2)+Math.floor(e/3))%2===0;case d.Patterns.PATTERN101:return t*e%2+t*e%3===0;case d.Patterns.PATTERN110:return(t*e%2+t*e%3)%2===0;case d.Patterns.PATTERN111:return(t*e%3+(t+e)%2)%2===0;default:throw new Error("bad maskPattern:"+n)}}d.applyMask=function(t,e){let r=e.size;for(let o=0;o<r;o++)for(let i=0;i<r;i++)e.isReserved(i,o)||e.xor(i,o,Oe(t,i,o))};d.getBestMask=function(t,e){let r=Object.keys(d.Patterns).length,o=0,i=1/0;for(let s=0;s<r;s++){e(s),d.applyMask(s,t);let u=d.getPenaltyN1(t)+d.getPenaltyN2(t)+d.getPenaltyN3(t)+d.getPenaltyN4(t);d.applyMask(s,t),u<i&&(i=u,o=s)}return o}});var ct=g(ut=>{var N=j(),Q=[1,1,1,1,1,1,1,1,1,1,2,2,1,2,2,4,1,2,4,4,2,4,4,4,2,4,6,5,2,4,6,6,2,5,8,8,4,5,8,8,4,5,8,11,4,8,10,11,4,9,12,16,4,9,16,16,6,10,12,18,6,10,17,16,6,11,16,19,6,13,18,21,7,14,21,25,8,16,20,25,8,17,23,25,9,17,23,34,9,18,25,30,10,20,27,32,12,21,29,35,12,23,34,37,12,25,34,40,13,26,35,42,14,28,38,45,15,29,40,48,16,31,43,51,17,33,45,54,18,35,48,57,19,37,51,60,19,38,53,63,20,40,56,66,21,43,59,70,22,45,62,74,24,47,65,77,25,49,68,81],$=[7,10,13,17,10,16,22,28,15,26,36,44,20,36,52,64,26,48,72,88,36,64,96,112,40,72,108,130,48,88,132,156,60,110,160,192,72,130,192,224,80,150,224,264,96,176,260,308,104,198,288,352,120,216,320,384,132,240,360,432,144,280,408,480,168,308,448,532,180,338,504,588,196,364,546,650,224,416,600,700,224,442,644,750,252,476,690,816,270,504,750,900,300,560,810,960,312,588,870,1050,336,644,952,1110,360,700,1020,1200,390,728,1050,1260,420,784,1140,1350,450,812,1200,1440,480,868,1290,1530,510,924,1350,1620,540,980,1440,1710,570,1036,1530,1800,570,1064,1590,1890,600,1120,1680,1980,630,1204,1770,2100,660,1260,1860,2220,720,1316,1950,2310,750,1372,2040,2430];ut.getBlocksCount=function(t,e){switch(e){case N.L:return Q[(t-1)*4+0];case N.M:return Q[(t-1)*4+1];case N.Q:return Q[(t-1)*4+2];case N.H:return Q[(t-1)*4+3];default:return}};ut.getTotalCodewordsCount=function(t,e){switch(e){case N.L:return $[(t-1)*4+0];case N.M:return $[(t-1)*4+1];case N.Q:return $[(t-1)*4+2];case N.H:return $[(t-1)*4+3];default:return}}});var Yt=g(Z=>{var z=new Uint8Array(512),W=new Uint8Array(256);(function(){let t=1;for(let e=0;e<255;e++)z[e]=t,W[t]=e,t<<=1,t&256&&(t^=285);for(let e=255;e<512;e++)z[e]=z[e-255]})();Z.log=function(t){if(t<1)throw new Error("log("+t+")");return W[t]};Z.exp=function(t){return z[t]};Z.mul=function(t,e){return t===0||e===0?0:z[W[t]+W[e]]}});var Ot=g(V=>{var lt=Yt();V.mul=function(t,e){let r=new Uint8Array(t.length+e.length-1);for(let o=0;o<t.length;o++)for(let i=0;i<e.length;i++)r[o+i]^=lt.mul(t[o],e[i]);return r};V.mod=function(t,e){let r=new Uint8Array(t);for(;r.length-e.length>=0;){let o=r[0];for(let s=0;s<e.length;s++)r[s]^=lt.mul(e[s],o);let i=0;for(;i<r.length&&r[i]===0;)i++;r=r.slice(i)}return r};V.generateECPolynomial=function(t){let e=new Uint8Array([1]);for(let r=0;r<t;r++)e=V.mul(e,new Uint8Array([1,lt.exp(r)]));return e}});var Qt=g((Gn,Gt)=>{var jt=Ot();function at(n){this.genPoly=void 0,this.degree=n,this.degree&&this.initialize(this.degree)}at.prototype.initialize=function(t){this.degree=t,this.genPoly=jt.generateECPolynomial(this.degree)};at.prototype.encode=function(t){if(!this.genPoly)throw new Error("Encoder not initialized");let e=new Uint8Array(t.length+this.degree);e.set(t);let r=jt.mod(e,this.genPoly),o=this.degree-r.length;if(o>0){let i=new Uint8Array(this.degree);return i.set(r,o),i}return r};Gt.exports=at});var ft=g($t=>{$t.isValid=function(t){return!isNaN(t)&&t>=1&&t<=40}});var gt=g(B=>{var Wt="[0-9]+",je="[A-Z $%*+\\-./:]+",H="(?:[u3000-u303F]|[u3040-u309F]|[u30A0-u30FF]|[uFF00-uFFEF]|[u4E00-u9FAF]|[u2605-u2606]|[u2190-u2195]|u203B|[u2010u2015u2018u2019u2025u2026u201Cu201Du2225u2260]|[u0391-u0451]|[u00A7u00A8u00B1u00B4u00D7u00F7])+";H=H.replace(/u/g,"\\u");var Ge="(?:(?![A-Z0-9 $%*+\\-./:]|"+H+`)(?:.|[\r
]))+`;B.KANJI=new RegExp(H,"g");B.BYTE_KANJI=new RegExp("[^A-Z0-9 $%*+\\-./:]+","g");B.BYTE=new RegExp(Ge,"g");B.NUMERIC=new RegExp(Wt,"g");B.ALPHANUMERIC=new RegExp(je,"g");var Qe=new RegExp("^"+H+"$"),$e=new RegExp("^"+Wt+"$"),We=new RegExp("^[A-Z0-9 $%*+\\-./:]+$");B.testKanji=function(t){return Qe.test(t)};B.testNumeric=function(t){return $e.test(t)};B.testAlphanumeric=function(t){return We.test(t)}});var M=g(p=>{var Ze=ft(),dt=gt();p.NUMERIC={id:"Numeric",bit:1,ccBits:[10,12,14]};p.ALPHANUMERIC={id:"Alphanumeric",bit:2,ccBits:[9,11,13]};p.BYTE={id:"Byte",bit:4,ccBits:[8,16,16]};p.KANJI={id:"Kanji",bit:8,ccBits:[8,10,12]};p.MIXED={bit:-1};p.getCharCountIndicator=function(t,e){if(!t.ccBits)throw new Error("Invalid mode: "+t);if(!Ze.isValid(e))throw new Error("Invalid version: "+e);return e>=1&&e<10?t.ccBits[0]:e<27?t.ccBits[1]:t.ccBits[2]};p.getBestModeForData=function(t){return dt.testNumeric(t)?p.NUMERIC:dt.testAlphanumeric(t)?p.ALPHANUMERIC:dt.testKanji(t)?p.KANJI:p.BYTE};p.toString=function(t){if(t&&t.id)return t.id;throw new Error("Invalid mode")};p.isValid=function(t){return t&&t.bit&&t.ccBits};function Xe(n){if(typeof n!="string")throw new Error("Param is not a string");switch(n.toLowerCase()){case"numeric":return p.NUMERIC;case"alphanumeric":return p.ALPHANUMERIC;case"kanji":return p.KANJI;case"byte":return p.BYTE;default:throw new Error("Unknown mode: "+n)}}p.from=function(t,e){if(p.isValid(t))return t;try{return Xe(t)}catch{return e}}});var ee=g(R=>{var X=I(),ve=ct(),Zt=j(),S=M(),ht=ft(),vt=7973,Xt=X.getBCHDigit(vt);function tn(n,t,e){for(let r=1;r<=40;r++)if(t<=R.getCapacity(r,e,n))return r}function te(n,t){return S.getCharCountIndicator(n,t)+4}function en(n,t){let e=0;return n.forEach(function(r){let o=te(r.mode,t);e+=o+r.getBitsLength()}),e}function nn(n,t){for(let e=1;e<=40;e++)if(en(n,e)<=R.getCapacity(e,t,S.MIXED))return e}R.from=function(t,e){return ht.isValid(t)?parseInt(t,10):e};R.getCapacity=function(t,e,r){if(!ht.isValid(t))throw new Error("Invalid QR Code version");typeof r>"u"&&(r=S.BYTE);let o=X.getSymbolTotalCodewords(t),i=ve.getTotalCodewordsCount(t,e),s=(o-i)*8;if(r===S.MIXED)return s;let u=s-te(r,t);switch(r){case S.NUMERIC:return Math.floor(u/10*3);case S.ALPHANUMERIC:return Math.floor(u/11*2);case S.KANJI:return Math.floor(u/13);case S.BYTE:default:return Math.floor(u/8)}};R.getBestVersionForData=function(t,e){let r,o=Zt.from(e,Zt.M);if(Array.isArray(t)){if(t.length>1)return nn(t,o);if(t.length===0)return 1;r=t[0]}else r=t;return tn(r.mode,r.getLength(),o)};R.getEncodedBits=function(t){if(!ht.isValid(t)||t<7)throw new Error("Invalid QR Code version");let e=t<<12;for(;X.getBCHDigit(e)-Xt>=0;)e^=vt<<X.getBCHDigit(e)-Xt;return t<<12|e}});var ie=g(oe=>{var pt=I(),re=1335,rn=21522,ne=pt.getBCHDigit(re);oe.getEncodedBits=function(t,e){let r=t.bit<<3|e,o=r<<10;for(;pt.getBCHDigit(o)-ne>=0;)o^=re<<pt.getBCHDigit(o)-ne;return(r<<10|o)^rn}});var ue=g((vn,se)=>{var on=M();function x(n){this.mode=on.NUMERIC,this.data=n.toString()}x.getBitsLength=function(t){return 10*Math.floor(t/3)+(t%3?t%3*3+1:0)};x.prototype.getLength=function(){return this.data.length};x.prototype.getBitsLength=function(){return x.getBitsLength(this.data.length)};x.prototype.write=function(t){let e,r,o;for(e=0;e+3<=this.data.length;e+=3)r=this.data.substr(e,3),o=parseInt(r,10),t.put(o,10);let i=this.data.length-e;i>0&&(r=this.data.substr(e),o=parseInt(r,10),t.put(o,i*3+1))};se.exports=x});var le=g((tr,ce)=>{var sn=M(),wt=["0","1","2","3","4","5","6","7","8","9","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"," ","$","%","*","+","-",".","/",":"];function U(n){this.mode=sn.ALPHANUMERIC,this.data=n}U.getBitsLength=function(t){return 11*Math.floor(t/2)+6*(t%2)};U.prototype.getLength=function(){return this.data.length};U.prototype.getBitsLength=function(){return U.getBitsLength(this.data.length)};U.prototype.write=function(t){let e;for(e=0;e+2<=this.data.length;e+=2){let r=wt.indexOf(this.data[e])*45;r+=wt.indexOf(this.data[e+1]),t.put(r,11)}this.data.length%2&&t.put(wt.indexOf(this.data[e]),6)};ce.exports=U});var fe=g((er,ae)=>{var un=M();function q(n){this.mode=un.BYTE,typeof n=="string"?this.data=new TextEncoder().encode(n):this.data=new Uint8Array(n)}q.getBitsLength=function(t){return t*8};q.prototype.getLength=function(){return this.data.length};q.prototype.getBitsLength=function(){return q.getBitsLength(this.data.length)};q.prototype.write=function(n){for(let t=0,e=this.data.length;t<e;t++)n.put(this.data[t],8)};ae.exports=q});var de=g((nr,ge)=>{var cn=M(),ln=I();function D(n){this.mode=cn.KANJI,this.data=n}D.getBitsLength=function(t){return t*13};D.prototype.getLength=function(){return this.data.length};D.prototype.getBitsLength=function(){return D.getBitsLength(this.data.length)};D.prototype.write=function(n){let t;for(t=0;t<this.data.length;t++){let e=ln.toSJIS(this.data[t]);if(e>=33088&&e<=40956)e-=33088;else if(e>=57408&&e<=60351)e-=49472;else throw new Error("Invalid SJIS character: "+this.data[t]+`
Make sure your charset is UTF-8`);e=(e>>>8&255)*192+(e&255),n.put(e,13)}};ge.exports=D});var he=g((rr,mt)=>{"use strict";var K={single_source_shortest_paths:function(n,t,e){var r={},o={};o[t]=0;var i=K.PriorityQueue.make();i.push(t,0);for(var s,u,c,l,a,w,h,y,A;!i.empty();){s=i.pop(),u=s.value,l=s.cost,a=n[u]||{};for(c in a)a.hasOwnProperty(c)&&(w=a[c],h=l+w,y=o[c],A=typeof o[c]>"u",(A||y>h)&&(o[c]=h,i.push(c,h),r[c]=u))}if(typeof e<"u"&&typeof o[e]>"u"){var T=["Could not find a path from ",t," to ",e,"."].join("");throw new Error(T)}return r},extract_shortest_path_from_predecessor_list:function(n,t){for(var e=[],r=t,o;r;)e.push(r),o=n[r],r=n[r];return e.reverse(),e},find_path:function(n,t,e){var r=K.single_source_shortest_paths(n,t,e);return K.extract_shortest_path_from_predecessor_list(r,e)},PriorityQueue:{make:function(n){var t=K.PriorityQueue,e={},r;n=n||{};for(r in t)t.hasOwnProperty(r)&&(e[r]=t[r]);return e.queue=[],e.sorter=n.sorter||t.default_sorter,e},default_sorter:function(n,t){return n.cost-t.cost},push:function(n,t){var e={value:n,cost:t};this.queue.push(e),this.queue.sort(this.sorter)},pop:function(){return this.queue.shift()},empty:function(){return this.queue.length===0}}};typeof mt<"u"&&(mt.exports=K)});var Ae=g(F=>{var f=M(),me=ue(),ye=le(),Ee=fe(),Ce=de(),J=gt(),v=I(),an=he();function pe(n){return unescape(encodeURIComponent(n)).length}function Y(n,t,e){let r=[],o;for(;(o=n.exec(e))!==null;)r.push({data:o[0],index:o.index,mode:t,length:o[0].length});return r}function Be(n){let t=Y(J.NUMERIC,f.NUMERIC,n),e=Y(J.ALPHANUMERIC,f.ALPHANUMERIC,n),r,o;return v.isKanjiModeEnabled()?(r=Y(J.BYTE,f.BYTE,n),o=Y(J.KANJI,f.KANJI,n)):(r=Y(J.BYTE_KANJI,f.BYTE,n),o=[]),t.concat(e,r,o).sort(function(s,u){return s.index-u.index}).map(function(s){return{data:s.data,mode:s.mode,length:s.length}})}function yt(n,t){switch(t){case f.NUMERIC:return me.getBitsLength(n);case f.ALPHANUMERIC:return ye.getBitsLength(n);case f.KANJI:return Ce.getBitsLength(n);case f.BYTE:return Ee.getBitsLength(n)}}function fn(n){return n.reduce(function(t,e){let r=t.length-1>=0?t[t.length-1]:null;return r&&r.mode===e.mode?(t[t.length-1].data+=e.data,t):(t.push(e),t)},[])}function gn(n){let t=[];for(let e=0;e<n.length;e++){let r=n[e];switch(r.mode){case f.NUMERIC:t.push([r,{data:r.data,mode:f.ALPHANUMERIC,length:r.length},{data:r.data,mode:f.BYTE,length:r.length}]);break;case f.ALPHANUMERIC:t.push([r,{data:r.data,mode:f.BYTE,length:r.length}]);break;case f.KANJI:t.push([r,{data:r.data,mode:f.BYTE,length:pe(r.data)}]);break;case f.BYTE:t.push([{data:r.data,mode:f.BYTE,length:pe(r.data)}])}}return t}function dn(n,t){let e={},r={start:{}},o=["start"];for(let i=0;i<n.length;i++){let s=n[i],u=[];for(let c=0;c<s.length;c++){let l=s[c],a=""+i+c;u.push(a),e[a]={node:l,lastCount:0},r[a]={};for(let w=0;w<o.length;w++){let h=o[w];e[h]&&e[h].node.mode===l.mode?(r[h][a]=yt(e[h].lastCount+l.length,l.mode)-yt(e[h].lastCount,l.mode),e[h].lastCount+=l.length):(e[h]&&(e[h].lastCount=l.length),r[h][a]=yt(l.length,l.mode)+4+f.getCharCountIndicator(l.mode,t))}}o=u}for(let i=0;i<o.length;i++)r[o[i]].end=0;return{map:r,table:e}}function we(n,t){let e,r=f.getBestModeForData(n);if(e=f.from(t,r),e!==f.BYTE&&e.bit<r.bit)throw new Error('"'+n+'" cannot be encoded with mode '+f.toString(e)+`.
 Suggested mode is: `+f.toString(r));switch(e===f.KANJI&&!v.isKanjiModeEnabled()&&(e=f.BYTE),e){case f.NUMERIC:return new me(n);case f.ALPHANUMERIC:return new ye(n);case f.KANJI:return new Ce(n);case f.BYTE:return new Ee(n)}}F.fromArray=function(t){return t.reduce(function(e,r){return typeof r=="string"?e.push(we(r,null)):r.data&&e.push(we(r.data,r.mode)),e},[])};F.fromString=function(t,e){let r=Be(t,v.isKanjiModeEnabled()),o=gn(r),i=dn(o,e),s=an.find_path(i.map,"start","end"),u=[];for(let c=1;c<s.length-1;c++)u.push(i.table[s[c]].node);return F.fromArray(fn(u))};F.rawSplit=function(t){return F.fromArray(Be(t,v.isKanjiModeEnabled()))}});var Ie=g(Te=>{var et=I(),Et=j(),hn=Dt(),pn=kt(),wn=zt(),mn=Kt(),At=Jt(),Tt=ct(),yn=Qt(),tt=ee(),En=ie(),Cn=M(),Ct=Ae();function Bn(n,t){let e=n.size,r=mn.getPositions(t);for(let o=0;o<r.length;o++){let i=r[o][0],s=r[o][1];for(let u=-1;u<=7;u++)if(!(i+u<=-1||e<=i+u))for(let c=-1;c<=7;c++)s+c<=-1||e<=s+c||(u>=0&&u<=6&&(c===0||c===6)||c>=0&&c<=6&&(u===0||u===6)||u>=2&&u<=4&&c>=2&&c<=4?n.set(i+u,s+c,!0,!0):n.set(i+u,s+c,!1,!0))}}function An(n){let t=n.size;for(let e=8;e<t-8;e++){let r=e%2===0;n.set(e,6,r,!0),n.set(6,e,r,!0)}}function Tn(n,t){let e=wn.getPositions(t);for(let r=0;r<e.length;r++){let o=e[r][0],i=e[r][1];for(let s=-2;s<=2;s++)for(let u=-2;u<=2;u++)s===-2||s===2||u===-2||u===2||s===0&&u===0?n.set(o+s,i+u,!0,!0):n.set(o+s,i+u,!1,!0)}}function In(n,t){let e=n.size,r=tt.getEncodedBits(t),o,i,s;for(let u=0;u<18;u++)o=Math.floor(u/3),i=u%3+e-8-3,s=(r>>u&1)===1,n.set(o,i,s,!0),n.set(i,o,s,!0)}function Bt(n,t,e){let r=n.size,o=En.getEncodedBits(t,e),i,s;for(i=0;i<15;i++)s=(o>>i&1)===1,i<6?n.set(i,8,s,!0):i<8?n.set(i+1,8,s,!0):n.set(r-15+i,8,s,!0),i<8?n.set(8,r-i-1,s,!0):i<9?n.set(8,15-i-1+1,s,!0):n.set(8,15-i-1,s,!0);n.set(r-8,8,1,!0)}function Nn(n,t){let e=n.size,r=-1,o=e-1,i=7,s=0;for(let u=e-1;u>0;u-=2)for(u===6&&u--;;){for(let c=0;c<2;c++)if(!n.isReserved(o,u-c)){let l=!1;s<t.length&&(l=(t[s]>>>i&1)===1),n.set(o,u-c,l),i--,i===-1&&(s++,i=7)}if(o+=r,o<0||e<=o){o-=r,r=-r;break}}}function Mn(n,t,e){let r=new hn;e.forEach(function(c){r.put(c.mode.bit,4),r.put(c.getLength(),Cn.getCharCountIndicator(c.mode,n)),c.write(r)});let o=et.getSymbolTotalCodewords(n),i=Tt.getTotalCodewordsCount(n,t),s=(o-i)*8;for(r.getLengthInBits()+4<=s&&r.put(0,4);r.getLengthInBits()%8!==0;)r.putBit(0);let u=(s-r.getLengthInBits())/8;for(let c=0;c<u;c++)r.put(c%2?17:236,8);return Sn(r,n,t)}function Sn(n,t,e){let r=et.getSymbolTotalCodewords(t),o=Tt.getTotalCodewordsCount(t,e),i=r-o,s=Tt.getBlocksCount(t,e),u=r%s,c=s-u,l=Math.floor(r/s),a=Math.floor(i/s),w=a+1,h=l-a,y=new yn(h),A=0,T=new Array(s),bt=new Array(s),rt=0,xe=new Uint8Array(n.buffer);for(let _=0;_<s;_++){let it=_<c?a:w;T[_]=xe.slice(A,A+it),bt[_]=y.encode(T[_]),A+=it,rt=Math.max(rt,it)}let ot=new Uint8Array(r),Rt=0,E,C;for(E=0;E<rt;E++)for(C=0;C<s;C++)E<T[C].length&&(ot[Rt++]=T[C][E]);for(E=0;E<h;E++)for(C=0;C<s;C++)ot[Rt++]=bt[C][E];return ot}function Pn(n,t,e,r){let o;if(Array.isArray(n))o=Ct.fromArray(n);else if(typeof n=="string"){let l=t;if(!l){let a=Ct.rawSplit(n);l=tt.getBestVersionForData(a,e)}o=Ct.fromString(n,l||40)}else throw new Error("Invalid data");let i=tt.getBestVersionForData(o,e);if(!i)throw new Error("The amount of data is too big to be stored in a QR Code");if(!t)t=i;else if(t<i)throw new Error(`
The chosen QR Code version cannot contain this amount of data.
Minimum version required to store current data is: `+i+`.
`);let s=Mn(t,e,o),u=et.getSymbolSize(t),c=new pn(u);return Bn(c,t),An(c),Tn(c,t),Bt(c,e,0),t>=7&&In(c,t),Nn(c,s),isNaN(r)&&(r=At.getBestMask(c,Bt.bind(null,c,e))),At.applyMask(r,c),Bt(c,e,r),{modules:c,version:t,errorCorrectionLevel:e,maskPattern:r,segments:o}}Te.create=function(t,e){if(typeof t>"u"||t==="")throw new Error("No input text");let r=Et.M,o,i;return typeof e<"u"&&(r=Et.from(e.errorCorrectionLevel,Et.M),o=tt.from(e.version),i=At.from(e.maskPattern),e.toSJISFunc&&et.setToSJISFunction(e.toSJISFunc)),Pn(t,o,r,i)}});var It=g(L=>{function Ne(n){if(typeof n=="number"&&(n=n.toString()),typeof n!="string")throw new Error("Color should be defined as hex string");let t=n.slice().replace("#","").split("");if(t.length<3||t.length===5||t.length>8)throw new Error("Invalid hex color: "+n);(t.length===3||t.length===4)&&(t=Array.prototype.concat.apply([],t.map(function(r){return[r,r]}))),t.length===6&&t.push("F","F");let e=parseInt(t.join(""),16);return{r:e>>24&255,g:e>>16&255,b:e>>8&255,a:e&255,hex:"#"+t.slice(0,6).join("")}}L.getOptions=function(t){t||(t={}),t.color||(t.color={});let e=typeof t.margin>"u"||t.margin===null||t.margin<0?4:t.margin,r=t.width&&t.width>=21?t.width:void 0,o=t.scale||4;return{width:r,scale:r?4:o,margin:e,color:{dark:Ne(t.color.dark||"#000000ff"),light:Ne(t.color.light||"#ffffffff")},type:t.type,rendererOpts:t.rendererOpts||{}}};L.getScale=function(t,e){return e.width&&e.width>=t+e.margin*2?e.width/(t+e.margin*2):e.scale};L.getImageWidth=function(t,e){let r=L.getScale(t,e);return Math.floor((t+e.margin*2)*r)};L.qrToImageData=function(t,e,r){let o=e.modules.size,i=e.modules.data,s=L.getScale(o,r),u=Math.floor((o+r.margin*2)*s),c=r.margin*s,l=[r.color.light,r.color.dark];for(let a=0;a<u;a++)for(let w=0;w<u;w++){let h=(a*u+w)*4,y=r.color.light;if(a>=c&&w>=c&&a<u-c&&w<u-c){let A=Math.floor((a-c)/s),T=Math.floor((w-c)/s);y=l[i[A*o+T]?1:0]}t[h++]=y.r,t[h++]=y.g,t[h++]=y.b,t[h]=y.a}}});var Me=g(nt=>{var Nt=It();function bn(n,t,e){n.clearRect(0,0,t.width,t.height),t.style||(t.style={}),t.height=e,t.width=e,t.style.height=e+"px",t.style.width=e+"px"}function Rn(){try{return document.createElement("canvas")}catch{throw new Error("You need to specify a canvas element")}}nt.render=function(t,e,r){let o=r,i=e;typeof o>"u"&&(!e||!e.getContext)&&(o=e,e=void 0),e||(i=Rn()),o=Nt.getOptions(o);let s=Nt.getImageWidth(t.modules.size,o),u=i.getContext("2d"),c=u.createImageData(s,s);return Nt.qrToImageData(c.data,t,o),bn(u,i,s),u.putImageData(c,0,0),i};nt.renderToDataURL=function(t,e,r){let o=r;typeof o>"u"&&(!e||!e.getContext)&&(o=e,e=void 0),o||(o={});let i=nt.render(t,e,o),s=o.type||"image/png",u=o.rendererOpts||{};return i.toDataURL(s,u.quality)}});var be=g(Pe=>{var Ln=It();function Se(n,t){let e=n.a/255,r=t+'="'+n.hex+'"';return e<1?r+" "+t+'-opacity="'+e.toFixed(2).slice(1)+'"':r}function Mt(n,t,e){let r=n+t;return typeof e<"u"&&(r+=" "+e),r}function _n(n,t,e){let r="",o=0,i=!1,s=0;for(let u=0;u<n.length;u++){let c=Math.floor(u%t),l=Math.floor(u/t);!c&&!i&&(i=!0),n[u]?(s++,u>0&&c>0&&n[u-1]||(r+=i?Mt("M",c+e,.5+l+e):Mt("m",o,0),o=0,i=!1),c+1<t&&n[u+1]||(r+=Mt("h",s),s=0)):o++}return r}Pe.render=function(t,e,r){let o=Ln.getOptions(e),i=t.modules.size,s=t.modules.data,u=i+o.margin*2,c=o.color.light.a?"<path "+Se(o.color.light,"fill")+' d="M0 0h'+u+"v"+u+'H0z"/>':"",l="<path "+Se(o.color.dark,"stroke")+' d="'+_n(s,i,o.margin)+'"/>',a='viewBox="0 0 '+u+" "+u+'"',h='<svg xmlns="http://www.w3.org/2000/svg" '+(o.width?'width="'+o.width+'" height="'+o.width+'" ':"")+a+' shape-rendering="crispEdges">'+c+l+`</svg>
`;return typeof r=="function"&&r(null,h),h}});var Le=g(O=>{var xn=xt(),St=Ie(),Re=Me(),Un=be();function Pt(n,t,e,r,o){let i=[].slice.call(arguments,1),s=i.length,u=typeof i[s-1]=="function";if(!u&&!xn())throw new Error("Callback required as last argument");if(u){if(s<2)throw new Error("Too few arguments provided");s===2?(o=e,e=t,t=r=void 0):s===3&&(t.getContext&&typeof o>"u"?(o=r,r=void 0):(o=r,r=e,e=t,t=void 0))}else{if(s<1)throw new Error("Too few arguments provided");return s===1?(e=t,t=r=void 0):s===2&&!t.getContext&&(r=e,e=t,t=void 0),new Promise(function(c,l){try{let a=St.create(e,r);c(n(a,t,r))}catch(a){l(a)}})}try{let c=St.create(e,r);o(null,n(c,t,r))}catch(c){o(c)}}O.create=St.create;O.toCanvas=Pt.bind(null,Re.render);O.toDataURL=Pt.bind(null,Re.renderToDataURL);O.toString=Pt.bind(null,function(n,t,e){return Un.render(n,e)})});var _e=Ve(Le());window.LinglanQR=_e.default;})();

const byId=id=>document.getElementById(id);
const form=byId('checkout');
const notice=byId('notice');
const money=value=>'NT$ '+value.toLocaleString('zh-TW');
const cart=new Map();
let menu=[];
let pending=null;
let busy=false;
const phoneForm=byId('phone-booking');
const bookingMessage=phoneForm.querySelector('[role="status"]');
const taipeiNow=Date.now()+8*3600000;
phoneForm.elements.day.min=new Date(taipeiNow).toISOString().slice(0,10);
phoneForm.elements.day.max=new Date(taipeiNow+30*86400000).toISOString().slice(0,10);
phoneForm.addEventListener('submit',async event=>{
  event.preventDefault();
  const submit=phoneForm.querySelector('button');
  if(submit.disabled) return;
  const data=Object.fromEntries(new FormData(phoneForm));
  data.guests=Number(data.guests);
  submit.disabled=true;
  bookingMessage.textContent='儲存中…';
  try {
    await api('phone-reservations',data);
    phoneForm.reset();
    byId('new-booking').open=false;
    bookingMessage.textContent='電話訂位已儲存，狀態為已確認。';
    await refresh('bookings');
    notice.textContent='電話訂位已儲存。';
  } catch(error) {
    bookingMessage.textContent=error.message;
  } finally {
    submit.disabled=false;
  }
});
function node(tag,text,className) {
  const el=document.createElement(tag);
  if(text!==undefined) el.textContent=text;
  if(className) el.className=className;
  return el;
}
function button(text,action) {
  const el=node('button',text);
  el.type='button';
  el.addEventListener('click',action);
  return el;
}
const RESTAURANT_NAME = window.restaurantConfig.name.trim() || '義式餐廳';
const SUPABASE_URL = window.restaurantConfig.supabaseUrl.trim();
const SUPABASE_PUBLISHABLE_KEY = window.restaurantConfig.supabasePublishableKey.trim();
const starterMenu = window.restaurantStarterMenu;
const starterById = new Map(starterMenu.map(dish=>[dish.id,dish]));
document.title = RESTAURANT_NAME+'｜點餐與訂位';
for(const label of document.querySelectorAll('[data-restaurant-name]'))label.textContent=RESTAURANT_NAME;
const clean = (value,max) => value.trim().slice(0,max);
const nowInTaipei = () => new Date(Date.now()+8*3600000).toISOString();
const isServiceTime = slot => /^\d{2}:\d{2}$/.test(slot) &&
  ((slot >= '11:30' && slot < '14:30') || (slot >= '17:30' && slot < '21:00'));
let db;
let pendingKey;
const uniqueId = () => crypto.randomUUID();

async function checked(operation) {
  const {data,error}=await operation;
  if(error) throw Object.assign(Error(error.message),{code:error.code});
  return data;
}
async function api(path,data) {
  const now=nowInTaipei();
  const today=now.slice(0,10);
  if(path==='menu') return checked(db.from('restaurant_menu').select('id,category,name,price,sold_out_date')
    .eq('active',true).order('category').order('name'));
  if(path==='reservations') {
    const rows=await checked(db.from('restaurant_bookings')
      .select('id,booking_date,booking_time,guests,guest_name,phone,note,status,table_label')
      .is('deleted_at',null).gte('booking_date',today).order('booking_date').order('booking_time'));
    return rows.map(row=>({...row,day:row.booking_date,slot:row.booking_time.slice(0,5),name:row.guest_name}));
  }
  if(path==='phone-reservations') {
    const {day,slot,guests,name,phone,note,table_label}=data;
    const date=new Date(day+'T00:00:00Z');
    const maxDay=new Date(Date.now()+(30*24+8)*3600000).toISOString().slice(0,10);
    const contact=clean(phone,30).replace(/[()\s-]/g,'');
    if(!Number.isFinite(date.valueOf()) || date.toISOString().slice(0,10)!==day ||
       date.getUTCDay()===1 || !isServiceTime(slot) || day+'T'+slot<=now.slice(0,16) || day>maxDay ||
       !Number.isInteger(guests) || guests<1 || guests>8 || !clean(name,50) || !/^\+?\d{8,15}$/.test(contact)) {
      throw Error('請確認日期、營業時段、人數與電話。');
    }
    return checked(db.from('restaurant_bookings').insert({booking_date:day,booking_time:slot,guests,
      guest_name:clean(name,50),phone:contact,note:clean(note,200),table_label:clean(table_label,20)||null}));
  }
  if(path==='reservation-status') {
    const rows=await checked(db.from('restaurant_bookings').update({status:data.status})
      .eq('id',data.id).eq('status','confirmed').is('deleted_at',null).select('id'));
    if(!rows.length) throw Error('訂位狀態已更新，請重新整理。');
    return rows;
  }
  if(path==='sales' && !data) {
    const rows=await checked(db.from('restaurant_sales')
      .select('id,service,table_label,payment,total,subtotal,discount_amount,created_at,staff_note,restaurant_sale_items(menu_id,name,quantity,unit_price)')
      .is('deleted_at',null).gte('created_at',today+'T00:00:00+08:00').order('created_at',{ascending:false}));
    return (await enrichSales(rows)).map(row=>({...row,display_time:new Intl.DateTimeFormat('zh-TW',
      {timeZone:'Asia/Taipei',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).format(new Date(row.created_at)),
      lines:row.variant_lines??row.restaurant_sale_items.map(item=>({name:item.name,qty:item.quantity}))}));
  }
  if(path==='sales') {
    const sale=await checked(db.rpc('restaurant_checkout_lines',{sale_id:data.id,service_mode:data.service,
      table_name:data.table||'',payment_mode:data.payment,items:Object.fromEntries(data.items.map(item=>[item.id,item.qty])),discount:Number(data.discount??0),order_note:data.note??'',request_lines:data.variants??null,expected_lines:data.expected_variants??null}));
    return Array.isArray(sale)?sale[0]:sale;
  }
  throw Error('找不到這項功能。');
}

function renderMenu(category) {
  const dishes=byId('dishes');
  dishes.replaceChildren();
  for(const dish of menu.filter(dish=>category==='全部'||dish.category===category)) {
    const el=button(dish.name,()=>change(dish,1));
    el.className='dish';
    el.append(node('small',money(dish.price)+(soldOut(dish)?' · 今日售完':'')));
    el.disabled=soldOut(dish);
    dishes.append(el);
  }
}
function change(dish,delta){if(delta>0)counterPick(dish);}
function setService() {
  const tableRequired=form.elements.service.value==='內用';
  byId('table-field').hidden=!tableRequired;
  form.elements.table.required=tableRequired;
}
form.elements.service.addEventListener('change',setService);
form.elements.discount.addEventListener('input',renderCart);
function savePending(draft) {
  pending=draft;
  try {
    if(draft) sessionStorage.setItem(pendingKey,JSON.stringify(draft));
    else sessionStorage.removeItem(pendingKey);
  } catch {}
}
async function checkoutTableConflict(draft) {
  if(draft.service!=='內用') return [];
  const existing=await checked(db.from('restaurant_sales').select('id').eq('id',draft.id).maybeSingle());
  if(existing) return [];
  const tickets=await checked(db.rpc('restaurant_open_tables_lines'));
  const label=draft.table.trim().toUpperCase();
  return tickets.filter(ticket=>ticket.service==='內用'&&ticket.table_label.trim().toUpperCase()===label&&(ticket.id!==draft.id||!sameQuantities(draft.items,ticket.lines)));
}
function recallTicket(ticket,discount=0) {
  form.elements.note.value=ticket.counter_notes??'';
  savePending(null);
  setAddon(null);
  setTicket({id:ticket.id,service:ticket.service,table:ticket.table_label,lines:ticket.lines,
    items:ticket.lines.map(({id,qty})=>({id,qty})),variant_lines:ticket.variant_lines??ticket.lines.map(x=>({...x,menu_id:x.id,note:''})),note:ticket.counter_notes??'',sent:true});
  cart.clear();
  for(const item of ticket.lines) cart.set(item.id,item.qty);
  form.elements.service.value=ticket.service;
  form.elements.table.value=ticket.table_label;
  const subtotal=ticket.lines.reduce((sum,item)=>sum+item.price*item.qty,0);
  form.elements.discount.value=String(Math.min(discount,subtotal));
  setService();
  document.querySelector('[data-tab="order"]').click();
  renderCart();
}
function showCheckoutConflict(tickets) {
  notice.replaceChildren(node('p','這個桌號已有待結帳單。請叫回原單核對後結帳，或修改目前訂單的桌號。'));
  for(const ticket of tickets) {
    const subtotal=ticket.lines.reduce((sum,item)=>sum+item.price*item.qty,0);
    notice.append(node('p','原單 '+ticket.table_label+' · '+(ticket.variant_lines??ticket.lines).map(item=>item.name+' × '+item.qty+(item.note?'〔'+item.note+'〕':'')).join('、')+' · '+money(subtotal)));
    if(!kitchenTicket?.sent) notice.append(button('把目前餐點加入此桌',()=>beginAddon(ticket,true)));
    notice.append(button('叫回這筆原單',()=>{
      if(busy) return;
      if(cart.size&&!confirm('將目前畫面切換為這筆原桌單，請確認餐點與份數。')) return;
      const discount=Number(form.elements.discount.value)||0;
      recallTicket(ticket,discount);
      notice.textContent='已叫回桌號 '+ticket.table_label+' 的原單，請核對餐點、折扣和付款方式後按結帳。';
      form.scrollIntoView({block:'nearest'});
    }));
  }
  notice.scrollIntoView({block:'nearest'});
}
form.addEventListener('submit',async event=>{
  event.preventDefault();
  if(pendingAmendment||amendSending){notice.textContent='請先重試並確認桌單異動結果，再結帳。';return;}
  if(busy||addContext||(!pending&&!cart.size)||(kitchenTicket&&!kitchenTicket.sent)) return;
  if(!pending) {
    if(!form.reportValidity()) return;
    savePending({id:kitchenTicket?.id??uniqueId(),service:form.elements.service.value,
      table:form.elements.table.value,payment:form.elements.payment.value,
      discount:Number(form.elements.discount.value),note:kitchenTicket?.sent?'':form.elements.note.value.trim(),variants:kitchenTicket?.sent?null:variantRequest(counterVariants),expected_variants:kitchenTicket?.sent?kitchenTicket.variant_lines??null:null,items:[...cart].map(([id,qty])=>({id,qty}))});
  }
  busy=true;
  renderCart();
  notice.textContent='正在記錄收款…';
  try {
    const tickets=await checkoutTableConflict(pending);
    if(tickets.length) {
      savePending(null);
      if(kitchenTicket&&!kitchenTicket.sent) setTicket(null);
      showCheckoutConflict(tickets);
      return;
    }
    const sale=await api('sales',pending);
    savePending(null);
    clearDraft();
    await refresh('sales');
    await refreshExistingCloseReport();
    if(staffRole==='owner'&&!byId('revenue').hidden) byId('report-form').requestSubmit();
    notice.textContent='已結帳 '+money(sale.total)+' · '+sale.payment+'，已入帳。';
    notice.scrollIntoView({block:'nearest'});
  } catch(error) {
    if(error.code==='23505'&&error.message.includes('此桌已有')) {
      const draft=pending;
      savePending(null);
      if(kitchenTicket&&!kitchenTicket.sent) setTicket(null);
      try {
        const tickets=await checkoutTableConflict(draft);
        if(tickets.length) showCheckoutConflict(tickets);
        else notice.textContent=error.message+'。請重新整理待結帳清單後叫回原單。';
      } catch {
        notice.textContent=error.message+'。請重新整理待結帳清單後叫回原單。';
      }
    } else if(error.code==='23505'&&kitchenTicket?.sent) {
      savePending(null);
      clearDraft();
      notice.textContent=error.message+'。請在今日交易核對紀錄。';
    } else if(error.code==='40001'){savePending(null);clearDraft();notice.textContent=error.message+'，請從待結帳重新叫回原單。';
    } else if(['22023','23514','23502','42501'].includes(error.code)) {
      savePending(null);
      notice.textContent='尚未入帳：'+error.message+'，請修正後再結帳。';
    } else {
      notice.textContent='結帳結果待確認。'+error.message+' 請用原按鈕重試。';
    }
    notice.scrollIntoView({block:'nearest'});
  } finally {
    busy=false;
    renderCart();
  }
});
const statuses={pending:'待確認',confirmed:'已確認',cancelled:'已取消',arrived:'已到店'};
function renderBookingOverview(records) {
  if(byId('booking-overview').hidden) return;
  const list=byId('booking-overview-list');
  list.replaceChildren();
  const today=nowInTaipei().slice(0,10);
  for(const booking of records.filter(row=>row.status!=='cancelled')) {
    const line=node('div',undefined,'line');
    const heading=node('div',undefined,'row');
    const dateLabel=booking.day===today?'今天 '+booking.day:booking.day;
    heading.append(node('strong',dateLabel+' '+booking.slot+' · '+booking.guests+' 位',booking.day===today?'booking-today':undefined),
      node('span',statuses[booking.status]??booking.status));
    const details=[booking.name,booking.phone,booking.table_label?'桌號 '+booking.table_label:'尚未排桌'];
    if(booking.note) details.push('備註 '+booking.note);
    line.append(heading,node('p',details.join(' · ')),bookingActions(booking));
    list.append(line);
  }
  if(!list.children.length) list.append(node('p','目前沒有近期訂位。','muted'));
  byId('booking-overview-status').textContent='';
}
async function refreshBookingOverview() {
  if(byId('booking-overview').hidden||byId('staff-app').hidden||document.hidden) return;
  const control=byId('booking-overview-refresh');
  if(control.disabled) return;
  control.disabled=true;
  try {renderBookingOverview(await api('reservations'));}
  catch(error){byId('booking-overview-status').textContent='訂位更新失敗：'+error.message;}
  finally {control.disabled=false;}
}
byId('booking-overview-refresh').addEventListener('click',refreshBookingOverview);

async function refresh(tab) {
  notice.textContent='';
  const list=byId(tab==='bookings'?'booking-list':'sale-list');
  list.replaceChildren(node('p','載入中…'));
  try {
    if(tab==='bookings') {
      const records=await api('reservations');
      renderBookingOverview(records);
      list.replaceChildren();
      if(!records.length) list.append(node('p','目前沒有訂位。'));
      for(const booking of records) {
        const line=node('div',undefined,'line');
        const heading=node('div',undefined,'row');
        heading.append(node('strong',booking.day+' '+booking.slot+' · '+booking.guests+' 位'),node('span',statuses[booking.status]));
        line.append(heading,node('p',booking.name+' · '+booking.phone+(booking.table_label?' · 桌號 '+booking.table_label:'')+(booking.note?' · '+booking.note:'')));
        const actions=booking.status==='pending' ? [['確認訂位','confirmed'],['取消','cancelled']] :
          booking.status==='confirmed' ? [['標記到店','arrived'],['取消','cancelled']] : [];
        const controls=node('div',undefined,'tabs');
        for(const [label,status] of actions) {
          controls.append(button(label,async()=>{
            for(const el of controls.children) el.disabled=true;
            try {await api('reservation-status',{id:booking.id,status});await refresh(tab);}
            catch(error){notice.textContent=error.message;for(const el of controls.children) el.disabled=false;}
          }));
        }
        controls.append(bookingActions(booking));
        line.append(controls);
        list.append(line);
      }
    } else {
      const records=await api('sales');
      list.replaceChildren(node('p',records.length+' 筆 · 合計 '+money(records.reduce((sum,sale)=>sum+sale.total,0))));
      for(const sale of records) {
        const line=node('div',undefined,'line');
        if(!sale.variant_lines&&sale.original_variant_lines)line.append(node('p','原始餐點需求（帳目已調整）：'+sale.original_variant_lines.map(x=>x.name+' × '+x.qty+(x.note?'〔'+x.note+'〕':'')).join('、')));
        if(sale.staff_note)line.append(node('p','櫃台備註：'+sale.staff_note,'message'));
        line.append(node('strong',sale.display_time+' · '+sale.service+' '+sale.table_label+' · '+money(sale.total)+' · '+sale.payment),
          node('p',sale.lines.map(item=>item.name+' × '+item.qty+(item.note?'〔'+item.note+'〕':'')).join('、')),saleActions(sale));
        list.append(line);
      }
    }
  } catch(error) {list.replaceChildren(node('p',error.message,'message'));}
}
for(const control of document.querySelectorAll('[data-tab]')) {
  control.addEventListener('click',()=>{
    for(const tab of document.querySelectorAll('[data-tab]')) {
      tab.setAttribute('aria-pressed',String(tab===control));
      byId(tab.dataset.tab).hidden=tab!==control;
    }
    const tab=control.dataset.tab;
    if(tab==='bookings'||tab==='sales') refresh(tab);
    if(tab==='kitchen') loadKitchen();
    if(tab==='open-tables') loadOpenTables();
    if(tab==='availability')void loadAvailability();
    if(tab==='close-report')void loadCloseReport();
    if(tab==='dining') void refreshDining();
    if(tab==='staff-admin') void loadStaff();
    if(tab==='menu-admin') loadCatalog().catch(error=>{notice.textContent=error.message;});
  });
}
for(const control of document.querySelectorAll('[data-refresh]')) control.addEventListener('click',()=>refresh(control.dataset.refresh));
async function start() {
  try {
    menu=await api('menu');
    const categories=byId('categories');
    categories.replaceChildren();
    for(const category of ['全部',...new Set(menu.map(dish=>dish.category))]) {
      const el=button(category,()=>{
        for(const option of categories.children) option.setAttribute('aria-pressed',String(option===el));
        renderMenu(category);
      });
      el.setAttribute('aria-pressed',String(category==='全部'));
      categories.append(el);
    }
    try{form.elements.note.value=sessionStorage.getItem(pendingKey+':counter-note')??'';}catch{}
    const draft=pending??kitchenTicket??(addContext?.request?{...addContext,items:addContext.request.items,note:addContext.request.note??''}:null);
    if(draft) {
      for(const {id,qty} of draft.items) cart.set(id,qty);
      for(const key of ['service','table','payment','discount','note']) {
        if(draft[key]!==undefined) form.elements[key].value=draft[key];
      }
      setService();
      notice.textContent=pending?'有一筆結帳結果待確認，可安全重試。':addContext?'有一筆加點待確認，請用原按鈕重試。':kitchenTicket.sent?'已送廚房。':'有一筆出餐單待確認，可安全重試。';
    }
    if(addContext) {
      form.elements.service.value=addContext.service;
      form.elements.table.value=addContext.table;
      form.elements.note.value=addContext.request?.note??addContext.note??'';
      setService();
    }
    if(!kitchenTicket?.sent){
      const frozen=pending?.variants??kitchenTicket?.variants??addContext?.request?.variants;
      if(frozen)counterVariants=frozen;
      else if(!counterVariants.length){try{counterVariants=JSON.parse(sessionStorage.getItem(pendingKey+':variant-draft'))??[];}catch{}}
      if(!counterVariants.length&&draft?.items)counterVariants=legacyVariants(draft.items);
      if(pending&&!pending.variants&&!kitchenTicket?.sent)savePending({...pending,variants:variantRequest(counterVariants)});
      if(kitchenTicket&&!kitchenTicket.sent&&!kitchenTicket.variants)setTicket({...kitchenTicket,variants:variantRequest(counterVariants)});
      if(addContext?.request&&!addContext.request.variants)setAddon({...addContext,request:{...addContext.request,variants:variantRequest(counterVariants)}});
      syncCounterVariants();
    }
    renderMenu('全部');
    renderCart();
  } catch(error) {throw error;}
}
const login=byId('staff-login');
const loginStatus=byId('login-status');
const loginButton=login.querySelector('button');
async function enter(session) {
  const membership=await checked(db.from('restaurant_staff').select('role').eq('user_id',session.user.id).maybeSingle());
  if(!membership) {
    await db.auth.signOut({scope:'local'});
    throw Error('帳號已登入，但尚未加入餐廳員工名單。');
  }
  pendingKey='italian-bistro-cloud-sale:'+SUPABASE_URL+':'+session.user.id;
  try { pending=JSON.parse(sessionStorage.getItem(pendingKey)); } catch {}
  staffRole=membership.role;
  try { kitchenTicket=JSON.parse(sessionStorage.getItem(ticketKey())); } catch {}
  try { addContext=JSON.parse(sessionStorage.getItem(addonKey())); } catch {}
  for(const tab of ['menu-admin','staff-admin','revenue']) {
    document.querySelector('[data-tab="'+tab+'"]').hidden=staffRole!=='owner';
  }
  byId('report-form').elements.date.value=nowInTaipei().slice(0,10);
  byId('close-report-form').elements.day.value=nowInTaipei().slice(0,10);
  try{storeAmendment(JSON.parse(sessionStorage.getItem(amendmentStorageKey())));}catch{}
  if(staffRole==='kitchen') {
    for(const tab of ['order','bookings','sales','open-tables','dining','availability','close-report']) document.querySelector('[data-tab="'+tab+'"]').hidden=true;
    document.querySelector('[data-tab="kitchen"]').click();
  } else await start();
  login.hidden=true;
  byId('staff-app').hidden=false;
  void refreshKitchenAlerts();
  if(staffRole==='owner'||staffRole==='staff') {
    byId('workspace-sidebar').hidden=false;
    byId('booking-overview').hidden=false;
    byId('booking-overview-status').textContent='載入訂位中…';
    void refreshBookingOverview();
    void recoverBlockedDraft();
    void refreshDining();
    if(!diningTimer)diningTimer=setInterval(()=>{if(document.visibilityState==='visible')void refreshDining();},15000);
    setInterval(refreshBookingOverview,30000);
    document.addEventListener('visibilitychange',refreshBookingOverview);
  }
}
login.addEventListener('submit',async event=>{
  event.preventDefault();
  if(!db) return;
  loginButton.disabled=true;
  loginStatus.textContent='登入中…';
  try {
    const data=await checked(db.auth.signInWithPassword({email:login.elements.email.value.trim(),
      password:login.elements.password.value}));
    await enter(data.session);
  } catch(error) {
    loginStatus.textContent=error.message;
  } finally {
    login.elements.password.value='';
    loginButton.disabled=false;
  }
});
byId('sign-out').addEventListener('click',async()=>{
  if(busy) return;
  try {await checked(db.auth.signOut({scope:'local'}));location.reload();}
  catch(error){notice.textContent=error.message;}
});
async function init() {
  try {
    if(!SUPABASE_URL || !SUPABASE_PUBLISHABLE_KEY) {
      if(isDiningPage){
        byId('guest-order').hidden=false;login.hidden=true;byId('staff-heading').hidden=true;
        byId('guest-order-state').textContent='新餐廳尚未啟用桌碼點餐。';
      }else if(new URLSearchParams(location.search).get('view')==='staff'){
        loginStatus.textContent='員工工作台尚未連接新餐廳資料庫。';
      }else{
        await showGuestMenu(starterMenu);
      }
      return;
    }
    if(!window.supabase) throw Error('無法載入連線元件，請檢查網路後重新整理。');
    db=window.supabase.createClient(SUPABASE_URL,SUPABASE_PUBLISHABLE_KEY,isDiningPage?{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false}}:undefined);
    if(isDiningPage){await showGuestOrder();return;}
    if(isGuestPage) {await showGuestMenu();return;}
    db.auth.onAuthStateChange(event=>{
      if(event==='SIGNED_OUT' && !byId('staff-app').hidden) location.reload();
    });
    const {session}=await checked(db.auth.getSession());
    if(session) await enter(session);
  } catch(error) {(isDiningPage?byId('guest-order-state'):isGuestPage?byId('guest-status'):loginStatus).textContent=error.message;}
  finally {loginButton.disabled=!db;}
}
let staffRole;
let kitchenTicket;
const itemsObject=items=>Object.fromEntries(items.map(({id,qty})=>[id,qty]));
const menuBucket='restaurant-menu-images';
const diningKey=new URLSearchParams(location.hash.slice(1)).get('dine');
const isDiningPage=diningKey!==null;
const isGuestPage=new URLSearchParams(location.search).get('view')==='menu';
const ticketKey=()=>pendingKey+':kitchen';
const setTicket=ticket=>{
  kitchenTicket=ticket;
  try {
    if(ticket) sessionStorage.setItem(ticketKey(),JSON.stringify(ticket));
    else sessionStorage.removeItem(ticketKey());
  } catch {}
};
function picture(dish) {
  if(dish.image_path){
    const img=node('img');img.alt=dish.name;img.loading='lazy';
    img.src=db.storage.from(menuBucket).getPublicUrl(dish.image_path).data.publicUrl;
    return img;
  }
  return null;
}
async function showGuestMenu(previewMenu) {
  const section=byId('guest-menu');
  byId('guest-menu-title').textContent=RESTAURANT_NAME+'菜單';
  section.hidden=false;
  byId('staff-login').hidden=true;
  byId('staff-heading').hidden=true;
  const mode=document.querySelector('header .mode');
  mode.href='?view=staff';mode.textContent='員工工作台';
  const grid=byId('guest-dishes');
  const dishes=previewMenu??await checked(db.from('restaurant_menu')
    .select('id,category,name,price,image_path,active,sold_out_date')
    .eq('active',true).order('category').order('name'));
  const filters=byId('guest-categories');
  const categoryOrder=new Set(starterMenu.map(dish=>dish.category));
  const availableCategories=new Set(dishes.map(dish=>dish.category));
  const categories=[...new Set([...categoryOrder,...availableCategories])].filter(category=>availableCategories.has(category));
  function group(title,items){
    if(!items.length)return;
    const section=node('section',undefined,'guest-menu-group');
    const cards=node('div',undefined,'guest-menu-grid');
    section.append(node('h2',title),cards);
    for(const dish of items){
      const card=node('article',undefined,'panel guest-menu-item');
      const copy=node('div',undefined,'guest-menu-copy');
      copy.append(node('h3',dish.name+(soldOut(dish)?' · 今日售完':'')),node('strong',money(dish.price)));
      const description=starterById.get(dish.id)?.description;
      if(description)copy.append(node('p',description));
      card.append(copy);
      const image=picture(dish);if(image)card.append(image);
      cards.append(card);
    }
    grid.append(section);
  }
  function draw(category){
    grid.replaceChildren();
    for(const name of category==='全部'?categories:[category])group(name,dishes.filter(dish=>dish.category===name));
    if(!grid.children.length)grid.append(node('p','目前沒有供應中的餐點。'));
  }
  for(const category of ['全部',...categories]){
    const filter=button(category,()=>{
      for(const el of filters.children)el.setAttribute('aria-pressed',String(el===filter));
      draw(category);
    });
    filter.setAttribute('aria-pressed',String(category==='全部'));filters.append(filter);
  }
  draw('全部');
}
const menuForm=byId('edit-menu');
const menuPicker=byId('menu-picker');
let catalog=[];
async function loadCatalog(selected='') {
  catalog=await checked(db.from('restaurant_menu').select('id,name,category,price,active,image_path').order('category').order('name'));
  menuPicker.replaceChildren(new Option('新增餐點',''));
  for(const dish of catalog) menuPicker.add(new Option(dish.name+(dish.active?'':'（已下架）'),dish.id));
  menuPicker.value=selected;
  fillMenu();
}
function fillMenu() {
  menuForm.reset();
  const dish=catalog.find(d=>d.id===menuPicker.value);
  if(!dish) return;
  for(const key of ['name','category','price']) menuForm.elements[key].value=dish[key];
  menuForm.elements.active.checked=dish.active;
}
menuPicker.addEventListener('change',fillMenu);
const menuActions = node('div', undefined, 'actions');
const addMenuDish = button('新增餐點', () => {
  if (menuForm.querySelector('button[type="submit"]').disabled) return;
  menuPicker.value = '';
  fillMenu();
  menuForm.elements.name.focus();
});
menuActions.append(addMenuDish);
menuPicker.closest('label').after(menuActions);
function onForm(id,action) {
  const el=byId(id);
  el.addEventListener('submit',async event=>{
    event.preventDefault();
    const submit=el.querySelector('button[type="submit"]');
    submit.disabled=true;
    try {await action(el);}
    catch(error){notice.textContent=error.message;notice.scrollIntoView({block:'nearest'});}
    finally {submit.disabled=false;}
  });
}
onForm('edit-menu',async el=>{
  const selected=catalog.find(d=>d.id===menuPicker.value);
  const id=selected?.id??uniqueId();
  const file=el.elements.photo.files[0];
  const name=el.elements.name.value.trim();
  const category=el.elements.category.value.trim();
  const price=Number(el.elements.price.value);
  if(!name||!category||!Number.isInteger(price)||price<0||price>1000000) throw Error('請確認名稱、分類和售價。');
  let imagePath=selected?.image_path??null;
  if(file) {
    const extension={'image/jpeg':'jpg','image/png':'png','image/webp':'webp'}[file.type];
    if(!extension||file.size>5242880) throw Error('圖片請用 JPG、PNG 或 WebP，最大 5 MB。');
    imagePath=id+'/'+uniqueId()+'.'+extension;
    await checked(db.storage.from(menuBucket).upload(imagePath,file));
  }
  const entry={name,category,price,image_path:imagePath,active:el.elements.active.checked};
  await checked(selected?db.from('restaurant_menu').update(entry).eq('id',id):db.from('restaurant_menu').insert({...entry,id}));
  await loadCatalog(id);
  await start();
  notice.textContent='餐點已儲存。';
});
let staffAccounts=[];
let staffLoading=false;
let staffMutating=false;
const staffForm=byId('staff-form');
function resetStaffEditor() {
  staffForm.reset();
  staffForm.elements.id.value='';
  byId('staff-editor-title').textContent='新增員工';
}
async function staffRequest(body) {
  const {data,error}=await db.functions.invoke('restaurant-staff',{body});
  if(error) {
    let detail;
    try {detail=(await error.context.json()).message;} catch {}
    throw Error(detail||'員工管理連線失敗，請確認新版 restaurant-staff 函式已部署。');
  }
  if(data?.message || (!data?.ok && body.action!=='list')) throw Error(data?.message||'員工管理回應不完整，請更新 restaurant-staff 函式。');
  if(body.action==='list' && (data?.version!==8 || !Array.isArray(data.users))) throw Error('請先部署新版 restaurant-staff 函式，才能顯示員工清單。');
  return data;
}
async function loadStaff() {
  if(staffRole!=='owner'||staffLoading) return;
  staffLoading=true;
  byId('staff-refresh').disabled=true;
  byId('staff-status').textContent='載入帳號中…';
  try {
    const data=await staffRequest({action:'list'});
    staffAccounts=data.users;
    const list=byId('staff-list');list.replaceChildren();
    for(const account of staffAccounts) {
      const row=node('article',undefined,'booking-item');
      const roleName={owner:'管理者',staff:'櫃台',kitchen:'廚房'}[account.role]??'未授權／已移除員工資格';
      row.append(node('strong',account.name||account.email||'未設定姓名'),node('p',account.email),node('p',roleName+(account.self?'（目前登入）':'')));
      if(!account.self && account.role!=='owner') {
        const actions=node('div',undefined,'actions');
        actions.append(button('修改',()=>{
          if(staffMutating) return;
          staffForm.reset();
          staffForm.elements.id.value=account.id;
          staffForm.elements.name.value=account.name;
          staffForm.elements.email.value=account.email;
          staffForm.elements.role.value=account.role==='kitchen'?'kitchen':'staff';
          byId('staff-editor-title').textContent='修改員工';
          byId('staff-edit-status').textContent='';
          byId('staff-editor-title').scrollIntoView({block:'nearest'});
        }),button('刪除',()=>void deleteStaff(account)));
        row.append(actions);
      }
      list.append(row);
    }
    byId('staff-status').textContent=staffAccounts.length?'共 '+staffAccounts.length+' 個帳號':'目前沒有帳號。';
  } catch(error) {byId('staff-status').textContent=error.message;}
  finally {staffLoading=false;byId('staff-refresh').disabled=false;}
}
function lockStaff(value) {
  staffMutating=value;
  for(const control of staffForm.elements) control.disabled=value;
  for(const control of byId('staff-list').querySelectorAll('button')) control.disabled=value;
}
async function deleteStaff(account) {
  if(staffMutating || !confirm('確定刪除「'+account.email+'」的員工帳號？該員工將無法再操作；既有交易與訂位會保留。')) return;
  lockStaff(true);
  byId('staff-edit-status').textContent='正在刪除…';
  try {
    const data=await staffRequest({action:'delete',id:account.id});
    if(staffForm.elements.id.value===account.id) resetStaffEditor();
    byId('staff-edit-status').textContent=data.warning||'員工帳號已刪除。';
    await loadStaff();
  } catch(error) {byId('staff-edit-status').textContent=error.message;}
  finally {lockStaff(false);}
}
byId('staff-refresh').addEventListener('click',()=>{if(!staffMutating) void loadStaff();});
byId('staff-cancel').addEventListener('click',()=>{if(!staffMutating){resetStaffEditor();byId('staff-edit-status').textContent='';}});
onForm('staff-form',async el=>{
  if(staffMutating) return;
  const payload={action:'save',...Object.fromEntries(new FormData(el))};
  lockStaff(true);
  byId('staff-edit-status').textContent='儲存中…';
  try {
    await staffRequest(payload);
    resetStaffEditor();
    byId('staff-edit-status').textContent='員工帳號及權限已儲存。';
  } catch(error) {byId('staff-edit-status').textContent=error.message;}
  finally {
    el.elements.password.value='';
    lockStaff(false);
    await loadStaff();
  }
});
onForm('own-password-form',async el=>{
  const status=byId('own-password-status');
  try {
    if(staffRole!=='owner') throw Error('需要管理者權限。');
    const password=el.elements.password.value;
    if(password!==el.elements.confirm.value) throw Error('兩次新密碼不一致。');
    if(password.length<12 || new TextEncoder().encode(password).length>72) throw Error('新密碼至少 12 個字元，最多 72 位元組。');
    status.textContent='修改中…';
    await checked(db.auth.updateUser({password,current_password:el.elements.current.value}));
    el.reset();
    status.textContent='密碼已修改，下次登入請使用新密碼。';
  } catch(error) {status.textContent=error.message;}
  finally {for(const input of el.querySelectorAll('input[type="password"]')) input.value='';}
});
function revenueBounds(grain,date) {
  const start=new Date(date+'T00:00:00Z');
  if(grain==='year') start.setUTCMonth(0,1);
  if(grain==='month') start.setUTCDate(1);
  const end=new Date(start);
  if(grain==='year') end.setUTCFullYear(end.getUTCFullYear()+1);
  else if(grain==='month') end.setUTCMonth(end.getUTCMonth()+1);
  else end.setUTCDate(end.getUTCDate()+1);
  return [start,end].map(value=>value.toISOString().slice(0,10)+'T00:00:00+08:00');
}
async function revenueSales(grain,date) {
  const [start,end]=revenueBounds(grain,date);
  const rows=[];
  const pageSize=250;
  for(let offset=0;;offset+=pageSize) {
    const page=await checked(db.from('restaurant_sales')
      .select('id,created_at,table_label,service,payment,total,subtotal,discount_amount,staff_note,restaurant_sale_items(menu_id,name,quantity,unit_price)')
      .is('deleted_at',null).gte('created_at',start).lt('created_at',end)
      .order('created_at',{ascending:false}).order('id',{ascending:false})
      .range(offset,offset+pageSize-1));
    rows.push(...page);
    if(page.length<pageSize) return await enrichSales(rows);
  }
}
const reportTime=new Intl.DateTimeFormat('zh-TW',{timeZone:'Asia/Taipei',year:'numeric',month:'2-digit',
  day:'2-digit',hour:'2-digit',minute:'2-digit',hourCycle:'h23'});
function revenueDetail(sale) {
  const order=node('details',undefined,'revenue-order');
  const tableName=sale.table_label?'桌號 '+sale.table_label:sale.service;
  order.append(node('summary',reportTime.format(new Date(sale.created_at))+' · '+tableName+' · '+sale.payment+' · '+money(sale.total)));
  if(!sale.restaurant_sale_items.length) {
    order.append(node('p','這筆交易沒有餐點明細。','muted'));
    order.append(saleActions(sale));
    return order;
  }
  const table=node('table');
  table.setAttribute('aria-label','已結帳餐點明細');
  const heading=table.createTHead().insertRow();
  for(const title of ['餐點','份數','單價','小計']) {
    const cell=node('th',title);
    cell.scope='col';
    heading.append(cell);
  }
  const body=table.createTBody();
  for(const item of (sale.variant_lines??sale.restaurant_sale_items.map(x=>({...x,qty:x.quantity,price:x.unit_price,note:''})))) {
    const row=body.insertRow();
    for(const value of [item.name+(item.note?'〔'+item.note+'〕':''),item.qty,money(item.price),money(item.qty*item.price)]) {
      row.append(node('td',value));
    }
  }
  if(!sale.variant_lines&&sale.original_variant_lines)order.append(node('p','本交易帳目已調整，原始餐點需求供核對：'+sale.original_variant_lines.map(x=>x.name+' × '+x.qty+(x.note?'〔'+x.note+'〕':'')).join('、')));
  if(sale.staff_note)order.append(node('p','櫃台備註：'+sale.staff_note));
  order.append(table,node('p','餐點小計 '+money(sale.subtotal)+' · 折扣 '+money(sale.discount_amount)+' · 實收 '+money(sale.total)),saleActions(sale));
  return order;
}
onForm('report-form',async el=>{
  const result=byId('revenue-result');
  const details=byId('revenue-details');
  result.textContent='查詢中…';
  details.replaceChildren();
  try {
    const sales=await revenueSales(el.elements.grain.value,el.elements.date.value);
    result.textContent='營收 '+money(sales.reduce((sum,sale)=>sum+Number(sale.total),0))+' · '+sales.length+' 筆已結帳交易';
    if(!sales.length) {
      details.append(node('p','此期間沒有已結帳餐點。','muted'));
      return;
    }
    details.append(node('h3','已結帳餐點明細'));
    let cursor=0;
    const more=button('顯示更多交易',showMore);
    function showMore() {
      const batch=sales.slice(cursor,cursor+30).map(revenueDetail);
      more.before(...batch);
      cursor+=batch.length;
      more.hidden=cursor>=sales.length;
    }
    details.append(more);
    showMore();
    if(sales.length===1) details.querySelector('details').open=true;
  } catch(error) {result.textContent='';throw error;}
});
byId('kitchen-refresh').addEventListener('click',loadKitchen);
byId('send-kitchen').addEventListener('click',async()=>{
  if(addContext) {await sendAddon();return;}
  if(busy||pending||!cart.size||kitchenTicket?.sent) return;
  if(form.elements.service.value==='內用') {
    busy=true;renderCart();
    try {
      const rows=await checked(db.rpc('restaurant_open_tables_lines'));
      const label=form.elements.table.value.trim().toUpperCase();
      const matches=rows.filter(row=>row.service==='內用'&&row.table_label.trim().toUpperCase()===label);
      if(matches.length) {
        showCheckoutConflict(matches);
        return;
      }
    } catch(error) {notice.textContent=error.message;return;}
    finally{busy=false;renderCart();}
  }
  if(!kitchenTicket && !form.reportValidity()) return;
  if(!kitchenTicket) setTicket({id:uniqueId(),service:form.elements.service.value,table:form.elements.table.value,
    items:[...cart].map(([id,qty])=>({id,qty})),note:form.elements.note.value.trim(),variants:variantRequest(counterVariants),sent:false});
  busy=true;
  renderCart();
  try {
    await checked(db.rpc('restaurant_send_kitchen_lines',{ticket_id:kitchenTicket.id,mode:kitchenTicket.service,
      table_name:kitchenTicket.table,request_lines:kitchenTicket.variants,order_note:kitchenTicket.note??''}));
    clearDraft();
    notice.textContent='已送廚房並存到待結帳。可以開始點下一桌。';
  } catch(error){
    if(['23505','22023','23514','42501'].includes(error.code)) {
      setTicket(null);
      notice.textContent=error.message;
    } else notice.textContent=error.message+'。請用原單重試送出。';
  }
  finally{busy=false;renderCart();}
});

function clearDraft() {
  counterVariants=[];try{sessionStorage.removeItem(pendingKey+':variant-draft');}catch{}
  try{sessionStorage.removeItem(pendingKey+':counter-note');}catch{}
  setAddon(null);
  setTicket(null);
  cart.clear();
  form.reset();
  setService();
  renderCart();
}
byId('return-ticket').addEventListener('click',()=>{
  if(busy||pending||!kitchenTicket?.sent) return;
  clearDraft();
  document.querySelector('[data-tab="open-tables"]').click();
});
async function loadOpenTables() {
  const list=byId('tables-list');
  const query=byId('table-search').value.trim().toUpperCase();
  list.replaceChildren(node('p','讀取中…'));
  try {
    const [rows,counterNotes]=await Promise.all([checked(db.rpc('restaurant_open_tables_lines')),checked(db.rpc('restaurant_staff_kitchen_notes'))]);
    list.replaceChildren();
    for(const ticket of rows.filter(row=>!query||row.table_label.toUpperCase().includes(query))) {
      ticket.counter_notes=counterNotes.filter(x=>x.ticket_id===ticket.id).map(x=>(x.source==='addon'?'加點：':'首次點餐：')+x.note).join('；');
      const card=node('div',undefined,'line row');
      const summary=node('div');
      const total=ticket.lines.reduce((sum,item)=>sum+item.price*item.qty,0);
      const status=ticket.lines.length?{queued:'待製作',preparing:'製作中',served:'已出餐'}[ticket.status]:'尚未確認餐點';
      summary.append(node('strong',(ticket.table_label?'桌號 '+ticket.table_label:'外帶')+' · '+status+' · '+money(total)),
        node('p',(ticket.variant_lines??ticket.lines).map(item=>item.name+' × '+item.qty+(item.note?'〔'+item.note+'〕':'')).join('、')));
      if(ticket.counter_notes)summary.append(node('p','櫃台備註：'+ticket.counter_notes,'message counter-note-text'));
      card.append(summary,button('修改／退菜',()=>amendTicket(ticket)),button('加點',()=>beginAddon(ticket,cart.size>0)),button('叫回結帳',()=>{
        if(!ticket.lines.length){notice.textContent='本桌尚無確認餐點，請先到 QR 點餐確認或退回客單。';return;}
        if(busy||pending) {
          notice.textContent='請先確認目前結帳結果，再叫回其他桌單。';
          return;
        }
        if(cart.size&&!confirm('將目前畫面切換為這筆原桌單，請確認餐點與份數。')) return;
        recallTicket(ticket);
        notice.textContent='已叫回 '+(ticket.table_label?'桌號 '+ticket.table_label:'外帶單')+'，請確認付款方式。';
      }));
      list.append(card);
    }
    if(!list.children.length) list.append(node('p',query?'查無這個桌號的待結帳單。':'目前沒有待結帳單。'));
  } catch(error) {list.replaceChildren(node('p',error.message));}
}
byId('tables-refresh').addEventListener('click',loadOpenTables);
byId('table-search').addEventListener('keydown',event=>{
  if(event.key==='Enter'){event.preventDefault();loadOpenTables();}
});

function bookingExpected(row) {
  return {booking_date:row.booking_date,booking_time:row.booking_time,guests:row.guests,
    guest_name:row.guest_name,phone:row.phone,note:row.note,status:row.status,table_label:row.table_label};
}
function saleExpected(row) {
  const lines=[...row.restaurant_sale_items].sort((a,b)=>a.menu_id<b.menu_id?-1:a.menu_id>b.menu_id?1:0);
  return {service:row.service,table_label:row.table_label,payment:row.payment,total:row.total,subtotal:row.subtotal,discount_amount:row.discount_amount,lines};
}
function editDialog(title) {
  const modal=node('dialog',undefined,'edit-dialog');
  const editor=node('form');
  const actions=node('div',undefined,'tabs');
  const save=node('button','儲存修改','primary');
  save.type='submit';
  const cancel=button('取消',()=>modal.close());
  actions.append(save,cancel);
  const message=node('p',undefined,'message');
  message.setAttribute('role','status');
  editor.append(node('h2',title));
  modal.append(editor);
  modal.addEventListener('close',()=>modal.remove());
  document.body.append(modal);
  return {modal,editor,actions,message,save};
}
function field(parent,labelText,type,name,value,options) {
  const label=node('label',labelText);
  const control=node(options?'select':'input');
  if(options) for(const [key,text] of options) control.add(new Option(text,key));
  else control.type=type==='optional'?'text':type;
  control.name=name;
  control.value=value??'';
  if(type!=='optional') control.required=true;
  label.append(control);
  parent.append(label);
  return control;
}
function bookingActions(booking) {
  const actions=node('div',undefined,'tabs');
  actions.append(button('修改',()=>editBooking(booking)),button('刪除',async event=>{
    if(!confirm('刪除 '+booking.day+' '+booking.slot+' '+booking.name+' 的訂位？')) return;
    const control=event.currentTarget;
    control.disabled=true;
    try {
      await checked(db.rpc('restaurant_edit_booking',{booking_id:booking.id,expected:bookingExpected(booking),changes:{},remove_booking:true}));
      await refresh('bookings');
      notice.textContent='訂位已刪除。';
    } catch(error){notice.textContent=error.message;control.disabled=false;}
  }));
  return actions;
}
function editBooking(booking) {
  const {modal,editor,actions,message,save}=editDialog('修改訂位');
  const grid=node('div',undefined,'grid');
  const day=field(grid,'日期','date','booking_date',booking.booking_date);
  field(grid,'時間','time','booking_time',booking.slot).step='60';
  const guests=field(grid,'人數','number','guests',booking.guests);
  guests.min='1';guests.step='1';
  field(grid,'姓名','text','guest_name',booking.guest_name).maxLength=80;
  field(grid,'電話','tel','phone',booking.phone).maxLength=30;
  field(grid,'桌號（選填）','optional','table_label',booking.table_label).maxLength=20;
  field(grid,'狀態','text','status',booking.status,[['confirmed','已確認'],['arrived','已到店'],['cancelled','已取消']]);
  field(grid,'備註（選填）','optional','note',booking.note).maxLength=200;
  editor.append(grid,actions,message);
  editor.addEventListener('submit',async event=>{
    event.preventDefault();
    if(!day.value) return;
    const changes=Object.fromEntries(new FormData(editor));
    changes.guests=Number(changes.guests);
    save.disabled=true;
    try {
      await checked(db.rpc('restaurant_edit_booking',{booking_id:booking.id,expected:bookingExpected(booking),changes,remove_booking:false}));
      modal.close();
      await refresh('bookings');
      notice.textContent='訂位已修改。';
    } catch(error){message.textContent=error.message;}
    finally{save.disabled=false;}
  });
  modal.showModal();
}
async function updateReports() {
  // Refresh every cached financial view after a successful edit or deletion.
  const closeUpdate=refreshExistingCloseReport();
  await refresh('sales');
  byId('report-form').requestSubmit();
  await closeUpdate;
}
function saleActions(sale) {
  const actions=node('div',undefined,'tabs');
  if(staffRole!=='owner') return actions;
  actions.append(button('修改交易',()=>editSale(sale)),button('刪除交易',async event=>{
    if(!confirm('刪除此筆 '+money(sale.total)+' 的交易？營收將扣除此筆金額。')) return;
    const control=event.currentTarget;
    control.disabled=true;
    try {
      await checked(db.rpc('restaurant_edit_sale',{sale_id:sale.id,expected:saleExpected(sale),changes:{},remove_sale:true}));
      await updateReports();
      notice.textContent='交易已刪除，營收已更新。';
    } catch(error){notice.textContent=error.message;control.disabled=false;}
  }));
  return actions;
}
async function editSale(sale) {
  const {modal,editor,actions,message,save}=editDialog('修改已結帳交易');
  const grid=node('div',undefined,'grid');
  field(grid,'用餐方式','text','service',sale.service,[['內用','內用'],['外帶','外帶']]);
  field(grid,'桌號','optional','table_label',sale.table_label).maxLength=20;
  field(grid,'付款方式','text','payment',sale.payment,[['現金','現金'],['刷卡','刷卡'],['行動支付','行動支付']]);
  const discountField=field(grid,'折扣金額（元）','number','discount_amount',sale.discount_amount??0);
  discountField.min=0;discountField.step=1;
  const lines=node('div');
  let draft=sale.restaurant_sale_items.map(row=>({...row}));
  const total=node('p');
  const render=()=>{
    lines.replaceChildren();
    for(const item of draft) {
      const row=node('div',undefined,'line grid');
      row.append(node('strong',item.name));
      const quantity=field(row,'份數','number','',item.quantity);
      quantity.min=1;quantity.max=99;quantity.step=1;
      const price=field(row,'成交單價','number','',item.unit_price);
      price.min=0;price.max=1000000;price.step=1;
      const recalculate=()=>{
        item.quantity=Number(quantity.value);
        item.unit_price=Number(price.value);
        showTotal();
      };
      quantity.addEventListener('input',recalculate);
      price.addEventListener('input',recalculate);
      row.append(button('移除此餐點',()=>{draft=draft.filter(entry=>entry!==item);render();}));
      lines.append(row);
    }
    showTotal();
  };
  function showTotal(){
    const subtotal=draft.reduce((sum,item)=>sum+item.quantity*item.unit_price,0);
    const rebate=Number(discountField.value);
    const valid=discountField.value!==''&&Number.isInteger(rebate)&&rebate>=0&&rebate<=subtotal;
    discountField.setCustomValidity(valid?'':'折扣金額不可超過餐點小計。');
    total.textContent='餐點小計 '+money(subtotal)+' · 修改後實收 '+(valid?money(subtotal-rebate):'請確認折扣');
  }
  discountField.addEventListener('input',showTotal);
  const picker=node('select');
  picker.setAttribute('aria-label','加入餐點');
  picker.append(new Option('選擇要加入的餐點',''));
  for(const dish of menu) picker.add(new Option(dish.name+' · '+money(dish.price),dish.id));
  picker.addEventListener('change',()=>{
    const dish=menu.find(item=>item.id===picker.value);
    if(!dish) return;
    const existing=draft.find(item=>item.menu_id===dish.id);
    if(existing) existing.quantity=Math.min(existing.quantity+1,99);
    else draft.push({menu_id:dish.id,name:dish.name,unit_price:dish.price,quantity:1});
    picker.value='';render();
  });
  editor.append(grid,node('h3','餐點明細'),lines,picker,total,actions,message);
  render();
  editor.addEventListener('submit',async event=>{
    event.preventDefault();
    const values=Object.fromEntries(new FormData(editor));
    if(!draft.length){message.textContent='請保留至少一項餐點，或使用「刪除交易」。';return;}
    if(values.service==='內用'&&!values.table_label.trim()){message.textContent='請填寫桌號。';return;}
    save.disabled=true;
    try {
      await checked(db.rpc('restaurant_edit_sale',{sale_id:sale.id,expected:saleExpected(sale),
        changes:{service:values.service,table_label:values.table_label,payment:values.payment,discount_amount:Number(discountField.value),lines:draft},remove_sale:false}));
      modal.close();
      await updateReports();
      notice.textContent='交易已修改，營收已更新。';
    } catch(error){message.textContent=error.message;}
    finally{save.disabled=false;}
  });
  modal.showModal();
}

let addContext;
const addonKey=()=>pendingKey+':addon';
function setAddon(context) {
  addContext=context;
  try {
    if(context) sessionStorage.setItem(addonKey(),JSON.stringify(context));
    else sessionStorage.removeItem(addonKey());
  } catch {}
}
function sameQuantities(items,lines) {
  const left=itemsObject(items);
  const right=itemsObject(lines);
  return Object.keys(left).length===Object.keys(right).length &&
    Object.keys(left).every(id=>left[id]===right[id]);
}
function beginAddon(ticket,keepCurrent=false) {
  if(busy||pending||kitchenTicket?.sent||addContext?.request) {
    notice.textContent='請先確認目前送單或結帳結果，再進行加點。';
    return;
  }
  if(keepCurrent&&cart.size&&!confirm('將目前畫面上的餐點作為桌號 '+ticket.table_label+' 的新增餐點？')) return;
  if(!keepCurrent&&cart.size) {
    notice.textContent='目前已有未送出的餐點，可先在「櫃台點餐結帳」選擇桌號後送出加點。';
    return;
  }
  setTicket(null);
  if(!keepCurrent){counterVariants=[];saveCounterVariants();cart.clear();form.elements.note.value='';try{sessionStorage.removeItem(pendingKey+':counter-note');}catch{}}
  setAddon({ticket_id:ticket.id,table:ticket.table_label,service:ticket.service,note:form.elements.note.value});
  form.elements.service.value=ticket.service;
  form.elements.table.value=ticket.table_label;
  form.elements.discount.value='0';
  setService();
  document.querySelector('[data-tab="order"]').click();
  notice.textContent='正在為 '+(ticket.table_label?'桌號 '+ticket.table_label:'外帶單')+' 加點。請只選這次新增的餐點。';
  renderCart();
}
async function sendAddon() {
  if(busy||pending||!cart.size) return;
  if(!addContext?.request) {
    const items=[...cart].map(([id,qty])=>({id,qty}));
    setAddon({...addContext,request:{id:uniqueId(),items,note:form.elements.note.value.trim(),variants:variantRequest(counterVariants)}});
  }
  busy=true;
  renderCart();
  try {
    await checked(db.rpc('restaurant_add_items_lines',{ticket_id:addContext.ticket_id,
      request_id:addContext.request.id,request_lines:addContext.request.variants,order_note:addContext.request.note??''}));
    clearDraft();
    notice.textContent='加點已送廚房並併入原桌單，整桌用餐後一起結帳。';
  } catch(error) {
    if(['22023','23505','42501'].includes(error.code)) setAddon({...addContext,request:null});
    notice.textContent=error.message+(addContext?.request?'。請按原按鈕重試加點。':'');
  } finally {busy=false;renderCart();}
}
byId('cancel-addon').addEventListener('click',()=>{
  if(busy||addContext?.request) return;
  if(cart.size&&!confirm('放棄目前尚未送出的加點餐點？')) return;
  clearDraft();
  notice.textContent='已結束加點。';
});
async function recoverBlockedDraft() {
  if(!pending||pending.service!=='內用') return;
  const draft=pending;
  try {
    const tickets=await checkoutTableConflict(draft);
    if(tickets.length&&pending===draft&&!busy) {
      savePending(null);
      if(!kitchenTicket?.sent) setTicket(null);
      showCheckoutConflict(tickets);
      renderCart();
    }
  } catch {}
}

// QR 點餐：客用與員工操作共用資料庫 RPC，客用路徑使用獨立匿名連線。
let diningRefreshing=false;
let diningTimer;
const diningStatus=byId('dining-status');
function diningURL(id) {
 const url=new URL(location.href);url.search='';url.hash='dine='+id;return url.href;
}
async function qrTableCard(data,label) {
 const image=new Image();
 await new Promise((resolve,reject)=>{image.onload=resolve;image.onerror=reject;image.src=data;});
 const canvas=document.createElement('canvas');canvas.width=440;canvas.height=530;
 const ctx=canvas.getContext('2d');ctx.fillStyle='white';ctx.fillRect(0,0,440,530);
 ctx.fillStyle='#243c2c';ctx.textAlign='center';ctx.font='bold 25px sans-serif';ctx.fillText(RESTAURANT_NAME,220,42);
 const text='桌號 '+label;ctx.font='bold 32px sans-serif';
 const size=Math.min(32,Math.floor(390/Math.max(ctx.measureText(text).width,1)*32));ctx.font='bold '+size+'px sans-serif';ctx.fillText(text,220,86);
 ctx.drawImage(image,60,108,320,320);
 ctx.font='22px sans-serif';ctx.fillText('掃碼點餐',220,468);ctx.font='16px sans-serif';ctx.fillText('送出後由店員確認，餐後至櫃台結帳',220,502);
 return canvas.toDataURL('image/png');
}
async function displayDiningQR(session) {
 const panel=byId('dining-qr');panel.replaceChildren();
 panel.append(node('h3','桌號 '+session.table_label+' · 固定點餐 QR Code'));
 const url=diningURL(session.id);
 if(!/^https?:$/.test(location.protocol)) {panel.append(node('p','請從已上線的網站開啟此功能，檔案網址無法供客人掃碼使用。'));return;}
 try {
  const raw=await window.LinglanQR.toDataURL(url,{width:320,margin:4,errorCorrectionLevel:'M'});
  const data=await qrTableCard(raw,session.table_label);
  const image=node('img');image.src=data;image.alt='桌號 '+session.table_label+' 點餐 QR Code';image.style.cssText='width:280px;max-width:100%;background:white';
  panel.append(image);
  const download=node('a','下載 QR 圖片');download.href=data;download.download='苓蘭-桌'+session.table_label+'-固定點餐.png';panel.append(download);
 } catch {panel.append(node('p','QR 圖片無法產生，可先使用下方點餐連結。'));}
 const link=node('a','開啟本桌點餐頁面');link.href=url;link.target='_blank';link.rel='noopener noreferrer';
 panel.append(node('p','此碼固定對應本桌，請列印貼在桌上。每批客人使用相同桌碼，無需店員開桌。'),link);
 const input=node('input');input.value=url;input.readOnly=true;input.setAttribute('aria-label','本桌點餐連結');
 panel.append(input,button('複製點餐連結',async()=>{
  try {await navigator.clipboard.writeText(url);diningStatus.textContent='點餐連結已複製。';}
  catch {input.focus();input.select();diningStatus.textContent='請長按連結欄位複製。';}
 }));
 panel.scrollIntoView({block:'nearest'});
}
async function refreshDining() {
 if(diningRefreshing||!['owner','staff'].includes(staffRole))return;
 diningRefreshing=true;
 try {
  const [sessions,requests]=await Promise.all([checked(db.rpc('restaurant_dining_list')),checked(db.rpc('restaurant_guest_pending_lines'))]);
  notifyGuestOrders(requests);
  const badge=byId('guest-order-badge');badge.hidden=false;
  badge.textContent=requests.length?'客人點餐待確認 '+requests.length+' 筆':'目前沒有客人點餐待確認';
  byId('guest-order-count').textContent=requests.length?'（'+requests.length+'）':'';
  const tables=byId('dining-tables');tables.replaceChildren();
  for(const session of sessions) {
   const row=node('div',undefined,'panel');
   const expired=!session.active;
   row.append(node('strong','桌號 '+session.table_label+(expired?' · 已停用':' · 可掃碼點餐')));
   row.append(button('顯示 QR Code',()=>void displayDiningQR(session)),button('停用桌碼',async event=>{
    if(!confirm('停用桌號 '+session.table_label+' 的 QR Code？一般結帳不需要停用。尚未確認的客單會退回，已送廚房的餐點仍需結帳。'))return;
    const control=event.currentTarget;control.disabled=true;
    try {await checked(db.rpc('restaurant_dining_close',{session_key:session.id}));byId('dining-qr').replaceChildren();await refreshDining();diningStatus.textContent='本桌點餐已關閉。';}
    catch(error){diningStatus.textContent=error.message;}finally{control.disabled=false;}
   }));tables.append(row);
  }
  if(!sessions.length) tables.append(node('p','尚未設定桌號。請輸入桌號產生固定 QR Code，之後不需重複建立。'));
  const list=byId('guest-order-pending');list.replaceChildren();
  for(const order of requests) {
   const card=node('article',undefined,'panel');
   card.append(node('h3','桌號 '+order.table_label+' · '+new Date(order.created_at).toLocaleString('zh-TW',{timeZone:'Asia/Taipei',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hour12:false})));
   for(const line of order.lines)card.append(node('p',line.name+' × '+line.qty+(line.note?'〔'+line.note+'〕':'')+' · '+money(line.price*line.qty)));
   if(order.note)card.append(node('p','客人備註：'+order.note,'message'));
   card.append(node('strong','本次小計 '+money(order.lines.reduce((sum,x)=>sum+x.price*x.qty,0))));
   if(order.expired)card.append(node('p','本桌已關閉或到期，請退回此單。'));
   const actions=node('div',undefined,'actions');
   for(const accept of [true,false]) {
    const control=button(accept?'確認並送廚房':'退回客單',async()=>{
     if(!confirm(accept?'確認這份餐點並送廚房？':'確定退回這份客人點餐？'))return;
     for(const b of actions.children)b.disabled=true;
     try {
      await checked(db.rpc('restaurant_guest_review_lines',{order_id:order.id,accept_order:accept}));
      byId('guest-review-status').textContent=accept?'桌號 '+order.table_label+' 已送廚房並併入原桌單。':'桌號 '+order.table_label+' 客單已退回。';
      await refreshDining();
     }catch(error){byId('guest-review-status').textContent=error.message;for(const b of actions.children)b.disabled=false;}
    });control.disabled=accept&&order.expired;actions.append(control);
   }
   card.append(actions);list.append(card);
  }
  if(!requests.length)list.append(node('p','目前沒有待確認的客人點餐。'));
 }catch(error){diningStatus.textContent=error.message;byId('guest-review-status').textContent=error.message;byId('guest-order-badge').textContent='客人點餐狀態無法載入，請至右側重新整理。';}
 finally{diningRefreshing=false;}
}
byId('guest-order-badge').addEventListener('click',()=>byId('guest-review-overview').scrollIntoView({block:'nearest'}));
byId('guest-pending-refresh').addEventListener('click',()=>void refreshDining());
byId('dining-refresh').addEventListener('click',()=>void refreshDining());
onForm('dining-open-form',async el=>{
 diningStatus.textContent='建立桌碼中…';
 try {
  const session=await checked(db.rpc('restaurant_dining_open',{table_name:el.elements.table.value}));
  await refreshDining();await displayDiningQR(session);
  diningStatus.textContent='固定桌碼已備妥，可下載圖片列印貼桌；之後每批客人直接掃碼即可。';
 }catch(error){diningStatus.textContent=error.message;}
});
let guestSession=null;
let guestVisit=null;
let guestMenu=[];
let guestFrozen=null;
let guestSending=false;
const guestBasket=new Map();
let guestCategory='全部';
let guestRefreshBusy=false;
const guestStoreKey='italian-bistro-guest:'+SUPABASE_URL+':'+diningKey;
function saveGuestDraft() {
 try {localStorage.setItem(guestStoreKey,JSON.stringify({items:[...guestBasket],note:byId('guest-note').value,frozen:guestFrozen,visit:guestVisit,variants:guestVariants}));}catch{}
}
async function refreshGuestState() {
 if(guestRefreshBusy)return;guestRefreshBusy=true;
 try {
  guestMenu=(await checked(db.from('restaurant_menu').select('id,category,name,price,image_path,active,sold_out_date').eq('active',true).order('category').order('name'))).map(d=>({...d,menuPrice:d.price}));
  guestSession=await checked(db.rpc('restaurant_guest_view_lines',{table_key:diningKey,visit_key:guestVisit}));
  byId('guest-table-title').textContent='桌號 '+guestSession.table+' · 自助點餐';
  byId('guest-new-visit').hidden=guestSession.active;
  byId('guest-order-state').textContent=guestSession.active?'選好餐點後送出，由店員確認製作。':'本次用餐已結束或桌碼停用；再次來店用餐可按「開始新的用餐」，或洽店員。';
  if(guestFrozen&&guestSession.orders.some(x=>x.id===guestFrozen.id)){guestVisit=guestSession.session_id;guestFrozen=null;guestVariants=[];guestBasket.clear();byId('guest-note').value='';saveGuestDraft();byId('guest-send-status').textContent='原單已送達，可在下方查看狀態。';}
  for(const dish of guestMenu){const old=guestSession.prices?.find(x=>x.id===dish.id);dish.price=old?.price??dish.menuPrice;}
  const list=byId('guest-history');list.replaceChildren();
  for(const order of guestSession.orders) {
   const card=node('article',undefined,'panel');
   const status=order.status==='pending'?'等待店員確認':order.status==='rejected'?'已退回':({served:'已出餐',preparing:'製作中',queued:'已確認，待製作'}[order.kitchen_status]??'店員已確認');
   card.append(node('strong',status+' · '+new Date(order.created_at).toLocaleTimeString('zh-TW',{hour:'2-digit',minute:'2-digit',hour12:false,timeZone:'Asia/Taipei'})));
   for(const line of order.lines)card.append(node('p',line.name+' × '+line.qty+(line.note?'〔'+line.note+'〕':'')));
   if(order.note)card.append(node('p','備註：'+order.note));if(order.reason)card.append(node('p',order.reason));list.append(card);
  }
  if(!guestSession.orders.length)list.append(node('p','本桌尚未送出餐點。'));
  renderGuestDishes();renderGuestBasket();
 }catch(error){byId('guest-order-state').textContent=error.message;guestSession=null;renderGuestDishes();renderGuestBasket();}
 finally{guestRefreshBusy=false;}
}
async function showGuestOrder() {
 byId('guest-order').hidden=false;login.hidden=true;byId('staff-heading').hidden=true;
 try {
  guestMenu=(await checked(db.from('restaurant_menu').select('id,category,name,price,image_path,active,sold_out_date').eq('active',true).order('category').order('name'))).map(d=>({...d,menuPrice:d.price}));
  try {
   const saved=JSON.parse(localStorage.getItem(guestStoreKey));
   if(saved){for(const [id,qty]of saved.items??[])if(Number.isInteger(qty)&&qty>0&&qty<=99)guestBasket.set(id,qty);byId('guest-note').value=String(saved.note??'').slice(0,300);guestFrozen=saved.frozen??null;guestVisit=saved.visit??null;guestVariants=saved.variants??guestFrozen?.variants??legacyVariants((saved.items??[]).map(([id,qty])=>({id,qty})));syncGuestVariants();if(guestFrozen&&!guestFrozen.variants)guestFrozen.variants=variantRequest(guestVariants);}
  }catch{}
  const tabs=byId('guest-order-categories');
  for(const category of ['全部',...new Set(guestMenu.map(x=>x.category))]) {
   const tab=button(category,()=>{guestCategory=category;for(const x of tabs.children)x.setAttribute('aria-pressed',String(x===tab));renderGuestDishes();});
   tab.setAttribute('aria-pressed',String(category==='全部'));tabs.append(tab);
  }
  await refreshGuestState();
  setInterval(()=>{if(document.visibilityState==='visible'&&!guestSending)void refreshGuestState();},15000);
 }catch(error){byId('guest-order-state').textContent=error.message;}
}
byId('guest-new-visit').addEventListener('click',async()=>{
 if(guestSending)return;
 if(guestFrozen){byId('guest-send-status').textContent='尚有一筆送單待確認，請先更新狀態或洽店員核對。';await refreshGuestState();return;}
 if(!confirm('目前確實在本桌開始新一次用餐？'))return;
 guestVisit=null;guestVariants=[];guestBasket.clear();byId('guest-note').value='';saveGuestDraft();await refreshGuestState();
});
byId('guest-note').addEventListener('input',saveGuestDraft);
byId('guest-state-refresh').addEventListener('click',()=>void refreshGuestState());
byId('guest-clear').addEventListener('click',()=>{
 if(guestSending||guestFrozen||!confirm('清空尚未送出的餐點？'))return;
 guestVariants=[];guestBasket.clear();byId('guest-note').value='';saveGuestDraft();renderGuestDishes();renderGuestBasket();
});
byId('guest-send').addEventListener('click',async()=>{
 if(guestSending||!guestSession?.active||!guestBasket.size)return;
 if(!guestFrozen&&!confirm('確認送出桌號 '+guestSession.table+' 的餐點？送出後由店員確認。'))return;
 if(!guestFrozen){guestFrozen={id:uniqueId(),items:Object.fromEntries(guestBasket),note:byId('guest-note').value.trim(),variants:variantRequest(guestVariants)};saveGuestDraft();}
 guestSending=true;renderGuestDishes();renderGuestBasket();
 const status=byId('guest-send-status');status.textContent='送出中…';
 try {
  const submitted=await checked(db.rpc('restaurant_guest_submit_lines',{table_key:diningKey,request_id:guestFrozen.id,request_lines:guestFrozen.variants,order_note:guestFrozen.note,visit_key:guestVisit??guestSession.session_id??null}));
  guestVisit=submitted.session_id;guestFrozen=null;guestVariants=[];guestBasket.clear();byId('guest-note').value='';saveGuestDraft();
  status.textContent='已送出，請等候店員確認。可在下方查看本桌餐點狀態。';
  await refreshGuestState();
 }catch(error){
  if(['22023','23514','42501'].includes(error.code)){guestFrozen=null;saveGuestDraft();status.textContent=error.message;}
  else status.textContent='送單結果待確認，請按「重試送出原單」，不要重複建立新單。'+error.message;
 }finally{guestSending=false;renderGuestDishes();renderGuestBasket();}
});

// 新單聲音與醒目提醒。iPad 必須先由使用者點選啟用。
let alarmContext=null,alarmEnabled=false,alarmPreference=false,knownGuestOrders=null,lastAlarmAt=0;
try{alarmPreference=localStorage.getItem('italian-bistro-sound:'+SUPABASE_URL)==='on';}catch{}
function updateSoundLabel(text) {
 byId('sound-toggle').textContent=alarmEnabled?'關閉聲音提醒':'啟用聲音提醒';
 byId('sound-status').textContent=text??(alarmEnabled?'聲音已啟用；待確認客單每 30 秒提醒一次。':'請點選啟用，並保持此頁開啟、裝置音量開啟。');
}
async function enableAlarm(preview=true) {
 try {
  const Audio=window.AudioContext||window.webkitAudioContext;if(!Audio)throw Error('這個瀏覽器不支援聲音提醒。');
  alarmContext??=new Audio();await alarmContext.resume();
  alarmEnabled=alarmContext.state==='running';alarmPreference=true;
  try{localStorage.setItem('italian-bistro-sound:'+SUPABASE_URL,'on');}catch{}
  updateSoundLabel(alarmEnabled?undefined:'請再點一次啟用聲音提醒。');if(preview&&alarmEnabled)playAlarm();
 }catch(error){alarmEnabled=false;updateSoundLabel(error.message);}
}
function playAlarm() {
 if(!alarmEnabled||alarmContext?.state!=='running')return;
 try {
  const start=alarmContext.currentTime;
  for(const [offset,frequency]of [[0,784],[0.25,988]]) {
   const tone=alarmContext.createOscillator(),gain=alarmContext.createGain();tone.frequency.value=frequency;
   gain.gain.setValueAtTime(0,start+offset);gain.gain.linearRampToValueAtTime(0.14,start+offset+0.015);
   gain.gain.exponentialRampToValueAtTime(0.001,start+offset+0.2);tone.connect(gain);gain.connect(alarmContext.destination);
   tone.start(start+offset);tone.stop(start+offset+0.22);
  }lastAlarmAt=Date.now();
 }catch{alarmEnabled=false;updateSoundLabel('聲音未能播放，請重新點選啟用。');}
}
byId('sound-toggle').addEventListener('click',async()=>{
 if(alarmEnabled){alarmEnabled=false;alarmPreference=false;try{localStorage.setItem('italian-bistro-sound:'+SUPABASE_URL,'off');}catch{}updateSoundLabel('聲音已關閉，仍會顯示醒目提醒。');}
 else await enableAlarm();
});
document.addEventListener('pointerdown',event=>{if(event.target.closest('#sound-toggle'))return;if(alarmPreference&&!alarmEnabled&&staffRole)void enableAlarm(false);});
function notifyGuestOrders(orders) {
 const incoming=new Set(orders.map(o=>o.id));
 const newOrder=knownGuestOrders!==null&&orders.some(o=>!knownGuestOrders.has(o.id));
 knownGuestOrders=incoming;
 byId('guest-review-overview').classList.toggle('has-pending',orders.length>0);
 byId('guest-order-badge').classList.toggle('has-pending',orders.length>0);
 if(orders.length&&(newOrder||Date.now()-lastAlarmAt>=30000))playAlarm();
}
let knownKitchenChanges=null;
function notifyKitchenChanges(changes){
 const unread=changes.filter(x=>!x.kitchen_seen_at);
 const hasNew=knownKitchenChanges!==null&&unread.some(x=>!knownKitchenChanges.has(x.id));
 knownKitchenChanges=new Set(unread.map(x=>x.id));
 byId('kitchen-change-count').textContent=unread.length?'（異動 '+unread.length+'）':'';
 byId('kitchen-change-alert').hidden=!unread.length;
 byId('kitchen-change-alert').textContent='廚房異動待確認 '+unread.length+' 筆';
 if(unread.length&&(hasNew||Date.now()-lastAlarmAt>=30000))playAlarm();
}
async function refreshKitchenAlerts(){
 if(!staffRole)return;
 try{notifyKitchenChanges(await checked(db.rpc('restaurant_ticket_change_list')));}catch{}
}
byId('kitchen-change-alert').addEventListener('click',()=>document.querySelector('[data-tab="kitchen"]').click());
let kitchenPollBusy=false,kitchenReloadQueued=false;
async function loadKitchen() {
 if(kitchenPollBusy){kitchenReloadQueued=true;return;}kitchenPollBusy=true;
 const list=byId('kitchen-list'),history=byId('kitchen-history-list');
 try {
  const [batches,notes,progress,changes,counterNotes]=await Promise.all([
   checked(db.rpc('restaurant_kitchen_variant_batches')),checked(db.rpc('restaurant_guest_kitchen_notes')),
   checked(db.rpc('restaurant_delivery_rows')),checked(db.rpc('restaurant_ticket_change_list')),checked(db.rpc('restaurant_staff_kitchen_notes'))]);
  notifyKitchenChanges(changes);
  list.replaceChildren();history.replaceChildren();
  for(const change of changes) {
   const card=node('article',undefined,'panel kitchen-change');
   card.classList.toggle('has-pending',!change.kitchen_seen_at);
   card.append(node('h3',(change.table_label?'桌號 '+change.table_label:change.service)+' · '+(!change.after_lines.length?'整桌取消':'餐點異動')));
   for(const before of change.before_lines) {
    const after=change.after_lines.find(x=>variantKey(x)===variantKey(before));const qty=after?.qty??0;
    if(qty!==before.qty)card.append(node('p',before.name+(before.note?'〔'+before.note+'〕':'')+'：'+before.qty+' → '+qty+' 份'+(qty<before.qty?'（退 '+(before.qty-qty)+' 份）':'（增加 '+(qty-before.qty)+' 份）')));
   }
   card.append(node('p','原因：'+change.reason));
   if(change.kitchen_seen_at)card.append(node('small','確認時間：'+new Date(change.kitchen_seen_at).toLocaleString('zh-TW',{timeZone:'Asia/Taipei',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hour12:false})));
   if(!change.kitchen_seen_at)card.append(button('廚房已確認異動',async event=>{
    event.currentTarget.disabled=true;
    try{await checked(db.rpc('restaurant_ticket_change_ack',{change_id:change.id}));await loadKitchen();}
    catch(error){notice.textContent=error.message;event.currentTarget.disabled=false;}
   }));else card.append(node('small','廚房已確認'));
   (change.kitchen_seen_at?history:list).append(card);
  }
  for(const batch of batches) {
   const card=node('article',undefined,'panel kitchen-batch');
   const guest=notes.find(x=>x.batch_id===batch.id);
   card.append(node('h3',batch.service+(batch.table_label?' · 桌號 '+batch.table_label:'')+(guest?' · 客人點餐':batch.source==='addon'?' · 加點':' · 首次點餐')+' · '+({queued:'待製作',preparing:'製作中',served:'已出餐'}[batch.status])));
   if(guest?.note)card.append(node('p','客人備註：'+guest.note,'message'));
   const counterNote=counterNotes.find(x=>x.source===batch.source&&x.batch_id===batch.id)?.note;
   if(counterNote)card.append(node('p','櫃台備註：'+counterNote,'message counter-note-text'));
   if(batch.status==='served')card.append(node('small','點餐時間：'+new Date(batch.created_at).toLocaleString('zh-TW',{timeZone:'Asia/Taipei',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hour12:false})));
   for(const item of batch.lines) {
    const p=progress.find(x=>x.source===batch.source&&x.batch_id===batch.id&&x.menu_id===item.id);
    const done=p?.delivered??(batch.status==='served'?item.qty:0);
    const row=node('div',undefined,'line row');
    if(item.note)row.append(node('p','需求：'+item.note,'variant-note'));
    row.append(node('strong',item.name+' × '+item.qty),node('span','已送 '+done+'／'+item.qty+' · 未送 '+Math.max(0,item.qty-done)));
    if(batch.status!=='served'&&done<item.qty)row.append(button('送出 1 份',async event=>{
     const control=event.currentTarget;control.disabled=true;
     try{await checked(db.rpc('restaurant_deliver_item',{kind:batch.source,batch:batch.id,item_id:item.id,expected_quantity:item.qty,expected_delivered:done}));await loadKitchen();}
     catch(error){notice.textContent=error.message;control.disabled=false;}
    }));card.append(row);
   }
   if(batch.status==='queued')card.append(button('開始製作',async event=>{
    const control=event.currentTarget;control.disabled=true;
    try{await checked(db.rpc('restaurant_batch_status',{batch_id:batch.id,batch_source:batch.source,old_status:'queued',new_status:'preparing'}));await loadKitchen();}
    catch(error){notice.textContent=error.message;control.disabled=false;}
   }));
   (batch.status==='served'?history:list).append(card);
  }
  const archived=history.children.length;
  byId('kitchen-history').hidden=!archived;
  byId('kitchen-history-summary').textContent='已完成出餐與已確認異動（'+archived+'）';
  if(!list.children.length)list.append(node('p','目前沒有待出餐或待確認異動。'));
 }catch(error){list.replaceChildren(node('p',error.message));history.replaceChildren();byId('kitchen-history').hidden=true;}
 finally{kitchenPollBusy=false;if(kitchenReloadQueued){kitchenReloadQueued=false;void loadKitchen();}}
}
let availabilityMenu=[];
function soldOut(dish){return dish.sold_out_date===nowInTaipei().slice(0,10);}
async function loadAvailability() {
 const list=byId('availability-list');list.replaceChildren(node('p','讀取中…'));
 try {
  availabilityMenu=await checked(db.from('restaurant_menu').select('id,name,category,price,active,sold_out_date').eq('active',true).order('category').order('name'));
  list.replaceChildren();
  for(const dish of availabilityMenu) {
   const row=node('div',undefined,'line row');row.append(node('strong',dish.name+' · '+(soldOut(dish)?'今日售完':'供應中')));
   row.append(button(soldOut(dish)?'恢復供應':'設為今日售完',async event=>{
    const control=event.currentTarget;control.disabled=true;
    try{await checked(db.rpc('restaurant_set_sold_out',{menu_id:dish.id,unavailable:!soldOut(dish)}));await loadAvailability();await start();notice.textContent='餐點供應狀態已更新。';}
    catch(error){notice.textContent=error.message;control.disabled=false;}
   }));list.append(row);
  }
 }catch(error){list.replaceChildren(node('p',error.message));}
}
let pendingAmendment=null,amendSending=false;
const amendmentStorageKey=()=>pendingKey+':amendment';
function storeAmendment(value) {
 pendingAmendment=value;
 try{if(value)sessionStorage.setItem(amendmentStorageKey(),JSON.stringify(value));else sessionStorage.removeItem(amendmentStorageKey());}catch{}
 byId('amendment-retry').hidden=!value;
}
async function sendAmendment(payload) {
 if(amendSending)throw Error('正在儲存桌單異動，請稍候。');
 amendSending=true;storeAmendment(payload);
 try {
  await checked(db.rpc('restaurant_ticket_amend_lines',payload));
  storeAmendment(null);
  if(kitchenTicket?.id===payload.ticket_id)clearDraft();
  notice.textContent='餐點異動已儲存，請提醒廚房查看異動通知。';
  await loadOpenTables();void refreshDining();
  if(!byId('kitchen').hidden)void loadKitchen();
 }catch(error){if(['22023','40001','42501','23514'].includes(error.code))storeAmendment(null);throw error;}
 finally{amendSending=false;}
}
byId('amendment-retry').addEventListener('click',async()=>{
 if(!pendingAmendment)return;
 try{await sendAmendment(pendingAmendment);}catch(error){notice.textContent=error.message+'；請核對桌單或用原按鈕重試。';}
});
function amendTicket(ticket) {
 if(pending||pendingAmendment||busy){notice.textContent='請先確認目前收款或桌單異動結果，再修改餐點。';return;}
 const editLines=ticket.variant_lines??ticket.lines.map(x=>({...x,menu_id:x.id,source:'original',batch_id:ticket.id,note:''}));
 const {modal,editor,actions,message,save}=editDialog('桌號 '+(ticket.table_label||'外帶')+' · 修改／退菜');
 editor.append(node('p',ticket.lines.length?'填 0 代表退掉該品項；全部填 0 會取消整桌。增加份數會另送廚房，已送出的退菜請同時通知廚房。':'本桌尚無確認餐點。填寫原因並儲存，將取消本次桌單、退回待確認客單，並結束本次用餐。'));
 const inputs=new Map();
 for(const item of editLines){const input=field(editor,item.name+(item.note?'〔'+item.note+'〕':'')+'（原 '+item.qty+' 份）','number','qty-'+item.id,item.qty);input.min='0';input.max='99';input.step='1';input.required=true;inputs.set(variantKey(item),input);}
 const reason=field(editor,'異動原因（必填）','text','reason','');reason.required=true;reason.maxLength=200;
 const cancelAll=button('整桌取消',()=>{for(const input of inputs.values())input.value='0';reason.focus();});
 actions.prepend(cancelAll);editor.append(actions,message);
 let frozen=null;
 editor.addEventListener('submit',async event=>{
  event.preventDefault();if(amendSending)return;
  if(!frozen){
   if(!editor.reportValidity())return;
   const quantities=Object.fromEntries([...inputs].map(([id,input])=>[id,Number(input.value)]));
   if(!reason.value.trim()){message.textContent='請填異動原因。';return;}
   if(editLines.length&&editLines.every(x=>quantities[variantKey(x)]===x.qty)){message.textContent='尚未變更份數。';return;}
   if(!confirm('確認變更桌號 '+ticket.table_label+' 的餐點？廚房會收到異動紀錄。'))return;
   frozen={ticket_id:ticket.id,request_id:uniqueId(),expected:editLines,quantities,change_reason:reason.value.trim()};
  }
  save.disabled=true;for(const input of editor.querySelectorAll('input'))input.disabled=true;cancelAll.disabled=true;
  try{await sendAmendment(frozen);modal.close();}
  catch(error){message.textContent=error.message+(pendingAmendment?'；結果待確認，請用原按鈕重試。':'；請重新查詢桌單後修改。');if(!pendingAmendment){frozen=null;for(const input of editor.querySelectorAll('input'))input.disabled=false;cancelAll.disabled=false;}}
  finally{save.disabled=false;save.textContent=pendingAmendment?'重試儲存原異動':'儲存修改';}
 });modal.showModal();
}
let closeReport=null,closeRequest=0,closeLoading=false,closeCashDay=null,closeExporting=false;
function cashCheck() {
 const value=byId('counted-cash').value;
 byId('cash-difference').textContent=value===''||!closeReport?'':Number.isInteger(Number(value))&&Number(value)>=0?'現金差額 '+money(Number(value)-closeReport.cash):'請輸入非負整數';
}
function invalidateCloseReport(message='請重新查詢收班報表。') {
 closeReport=null;byId('close-download').disabled=true;
 byId('close-report-result').replaceChildren();cashCheck();
 byId('close-report-status').textContent=message;
}
async function loadCloseReport() {
 const el=byId('close-report-form'),day=el.elements.day.value;
 if(!day||!['owner','staff'].includes(staffRole))return false;
 const request=++closeRequest;closeLoading=true;
 if(closeCashDay&&closeCashDay!==day)byId('counted-cash').value='';
 closeCashDay=day;
 invalidateCloseReport('正在更新 '+day+' 的收班報表…');
 try {
  const result=await checked(db.rpc('restaurant_close_report',{report_day:day}));
  if(request!==closeRequest||el.elements.day.value!==day)return false;
  closeReport=result;
  byId('close-report-status').textContent='已更新 '+result.day+' · '+new Date().toLocaleTimeString('zh-TW',{hour:'2-digit',minute:'2-digit',hour12:false,timeZone:'Asia/Taipei'})+'；已排除刪除交易，未結帳桌單為目前即時清單。';
  const target=byId('close-report-result');target.replaceChildren();
  const table=node('table');table.className='close-table';
  for(const [label,value]of [['已結帳筆數',result.count],['餐點小計',money(result.subtotal)],['折扣合計',money(result.discount)],['實收營業額',money(result.revenue)],['現金',money(result.cash)],['刷卡',money(result.card)],['行動支付',money(result.mobile)],['當日整桌取消',result.cancelled]]){
   const row=table.insertRow();row.append(node('th',label),node('td',String(value)));
  }target.append(table,node('h3','目前未結帳桌單'));
  for(const ticket of result.unpaid)target.append(node('p',(ticket.table_label?'桌號 '+ticket.table_label:ticket.service)+' · '+money(ticket.lines.reduce((sum,x)=>sum+x.price*x.qty,0))));
  if(!result.unpaid.length)target.append(node('p','目前沒有未結帳桌單。'));
  byId('close-download').disabled=closeExporting;cashCheck();return true;
 }catch(error){
  if(request===closeRequest)invalidateCloseReport('收班報表更新失敗，請重新查詢。'+error.message);
  return false;
 }finally{if(request===closeRequest)closeLoading=false;}
}
async function refreshExistingCloseReport() {
 if(closeReport||closeLoading||!byId('close-report').hidden)await loadCloseReport();
}
byId('counted-cash').addEventListener('input',cashCheck);
byId('close-report-form').elements.day.addEventListener('change',()=>{
 ++closeRequest;closeLoading=false;closeCashDay=null;
 byId('counted-cash').value='';invalidateCloseReport('日期已變更，請查詢收班報表。');
});
onForm('close-report-form',async()=>{await loadCloseReport();});
function refreshVisibleCloseReport(){
 if(document.visibilityState==='visible'&&!byId('close-report').hidden&&!closeLoading&&!closeExporting)void loadCloseReport();
}
setInterval(refreshVisibleCloseReport,15000);
document.addEventListener('visibilitychange',refreshVisibleCloseReport);
window.addEventListener('focus',refreshVisibleCloseReport);
function csvCell(value){let text=String(value??'');if(typeof value!=='number'&&/^[=+\-@\t\r]/.test(text))text="'"+text;return '"'+text.replaceAll('"','""')+'"';}
function reportCSV(r){
 const rows=[['義式餐廳 收班核對',r.day],['已結帳筆數',r.count],['餐點小計',r.subtotal],['折扣合計',r.discount],['營業額實收',r.revenue],['現金',r.cash],['刷卡',r.card],['行動支付',r.mobile],['當日整桌取消',r.cancelled]];
 const counted=byId('counted-cash').value;if(counted!=='')rows.push(['盤點當日現金實收',counted],['現金差額',Number(counted)-r.cash]);
 rows.push([],['交易編號','時間','用餐方式','桌號','付款方式','小計','折扣','實收']);
 for(const s of r.sales)rows.push([s.id,new Date(s.created_at).toLocaleString('zh-TW',{timeZone:'Asia/Taipei',hour12:false,year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit'}),s.service,s.table_label,s.payment,s.subtotal,s.discount_amount,s.total]);
 rows.push([],['目前未結帳（即時）','金額']);for(const t of r.unpaid)rows.push([t.table_label||t.service,t.lines.reduce((sum,x)=>sum+x.price*x.qty,0)]);
 return '\uFEFF'+rows.map(row=>row.map(csvCell).join(',')).join('\r\n');
}
byId('close-download').addEventListener('click',async()=>{
 if(closeExporting)return;
 const counted=byId('counted-cash').value;
 if(counted!==''&&(!Number.isInteger(Number(counted))||Number(counted)<0)){cashCheck();return;}
 closeExporting=true;byId('close-download').disabled=true;
 try {
  // Use a fresh database snapshot so exported revenue matches edits and deletions.
  if(!await loadCloseReport())return;
  const report=closeReport;
  if(!report||byId('close-report-form').elements.day.value!==report.day)return;
  const blob=new Blob([reportCSV(report)],{type:'text/csv;charset=utf-8;'}),url=URL.createObjectURL(blob),link=node('a');
  link.href=url;link.download='苓蘭收班-'+report.day+'.csv';document.body.append(link);link.click();link.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);
 }catch(error){byId('close-report-status').textContent='報表匯出失敗：'+error.message;}
 finally{closeExporting=false;byId('close-download').disabled=!closeReport;}
});

updateSoundLabel();
setInterval(()=>{if(staffRole&&document.visibilityState==='visible'){if(!byId('kitchen').hidden)void loadKitchen();else void refreshKitchenAlerts();}},15000);

form.elements.note.addEventListener('input',()=>{
 try{sessionStorage.setItem(pendingKey+':counter-note',form.elements.note.value);}catch{}
 if(addContext&&!addContext.request)setAddon({...addContext,note:form.elements.note.value});
});

// Each row has an independent identity, quantity and preparation note.
let counterVariants=[];
let guestVariants=[];
const variantRequest=rows=>rows.map(x=>({line_id:x.line_id??x.id,menu_id:x.menu_id??x.id,qty:x.qty,note:x.note??''}));
const variantKey=x=>x.source&&x.batch_id?x.source+':'+x.batch_id+':'+x.id:x.id;
function legacyVariants(items){return items.map(x=>({line_id:uniqueId(),menu_id:x.id,qty:x.qty,note:'',ice:'',sugar:'',extra:''}));}
function variantQuantity(rows,id){return rows.filter(x=>x.menu_id===id).reduce((s,x)=>s+x.qty,0);}
function syncCounterVariants(){cart.clear();for(const x of counterVariants)cart.set(x.menu_id,(cart.get(x.menu_id)??0)+x.qty);}
function syncGuestVariants(){guestBasket.clear();for(const x of guestVariants)guestBasket.set(x.menu_id,(guestBasket.get(x.menu_id)??0)+x.qty);}
function saveCounterVariants(){try{sessionStorage.setItem(pendingKey+':variant-draft',JSON.stringify(counterVariants));}catch{}}
function rowNote(x){return x.note?'需求：'+x.note:'依原餐點設定';}
function selectVariant(dish,existing,callback){
 const {modal,editor,actions,message,save}=editDialog(dish.name+' · 個別需求');save.textContent='加入這筆餐點';
 const quantity=field(editor,'這筆份數（相同需求）','number','quantity',existing?.qty??1);quantity.min='1';quantity.max='99';quantity.step='1';quantity.required=true;
 const drink=/飲|咖啡|茶|拿鐵|卡布|果汁|冰沙|café|cafe|tea|smoothie/i.test(dish.category+' '+dish.name);
 let ice=null,sugar=null;
 if(drink){
  if(!/熱/.test(dish.name))ice=field(editor,'冰量','optional','ice',existing?.ice??'',[['','依原設定'],['正常冰','正常冰'],['少冰','少冰'],['去冰','去冰']]);
  sugar=field(editor,'甜度','optional','sugar',existing?.sugar??'',[['','依原設定'],['正常糖','正常糖'],['半糖','半糖'],['微糖','微糖'],['無糖','無糖']]);
 }
 const extra=field(editor,'個別備註（選填）','optional','extra',existing?.extra??(existing?.note&&!existing?.ice&&!existing?.sugar?existing.note:''));extra.maxLength=240;
 editor.append(node('p','同款有不同需求，請另加一筆。這些選項不另加價；特殊需求以店員確認為準。'),actions,message);
 editor.addEventListener('submit',event=>{
  event.preventDefault();if(!editor.reportValidity())return;
  const qty=Number(quantity.value),note=[ice?.value,sugar?.value,extra.value.trim()].filter(Boolean).join('；');
  if(!Number.isInteger(qty)||qty<1||qty>99||note.length>300){message.textContent='請確認份數與需求字數。';return;}
  try{callback({line_id:existing?.line_id??uniqueId(),menu_id:dish.id,qty,note,ice:ice?.value??'',sugar:sugar?.value??'',extra:extra.value.trim()});modal.close();}
  catch(error){message.textContent=error.message;}
 });modal.showModal();
}
function upsertVariant(rows,row,existingId){
 const others=rows.filter(x=>x.line_id!==existingId);
 if(variantQuantity(others,row.menu_id)+row.qty>99)throw Error('同品項本次總份數不可超過 99。');
 const same=others.find(x=>x.menu_id===row.menu_id&&x.note===row.note);
 if(same)same.qty+=row.qty;else others.push(row);
 return others;
}
function counterPick(dish,existing=null,duplicate=false){
 if(!dish)return;
 if(busy||pending||kitchenTicket||addContext?.request)return;
 if(soldOut(dish)){notice.textContent='這項餐點今日已售完。';return;}
 const source=duplicate?{...existing,line_id:uniqueId(),qty:1}:existing;
 selectVariant(dish,source,row=>{
  counterVariants=upsertVariant(counterVariants,row,duplicate?null:existing?.line_id);
  syncCounterVariants();saveCounterVariants();renderCart();
 });
}
function renderCart(){
 const list=byId('cart');list.replaceChildren();let total=0;
 const readonly=busy||!!pending||!!kitchenTicket||!!addContext?.request;
 const rows=kitchenTicket?.sent?(kitchenTicket.variant_lines??kitchenTicket.lines??[]).map(x=>({...x,line_id:x.id,menu_id:x.menu_id??x.id})):counterVariants;
 for(const x of rows){
  const dish=kitchenTicket?.sent?x:menu.find(d=>d.id===x.menu_id);const price=dish?.price??0;total+=price*x.qty;
  const row=node('article',undefined,'line variant-row');
  row.append(node('strong',(dish?.name??'已下架餐點')+' × '+x.qty+' · '+money(price*x.qty)),node('p',rowNote(x),'variant-note'));
  if(!readonly){
   const controls=node('div',undefined,'actions');
   controls.append(button('修改需求',()=>counterPick(dish,x)),button('另加同款',()=>counterPick(dish,x,true)),button('移除這筆',()=>{
    counterVariants=counterVariants.filter(v=>v.line_id!==x.line_id);syncCounterVariants();saveCounterVariants();renderCart();
   }));row.append(controls);
  }list.append(row);
 }
 if(!rows.length)list.append(node('p','請選餐點並設定每筆需求。','muted'));
 byId('subtotal').textContent=money(total);const rebate=Number(form.elements.discount.value);
 const valid=form.elements.discount.value!==''&&Number.isInteger(rebate)&&rebate>=0&&rebate<=total;
 form.elements.discount.max=String(total);form.elements.discount.setCustomValidity(valid?'':'折扣金額不可超過小計。');
 byId('total').textContent=valid?money(total-rebate):'請確認折扣';
 form.elements.discount.disabled=!!pending||!!addContext;form.elements.note.disabled=readonly;
 byId('pay').disabled=busy||(!pending&&!cart.size)||(!!kitchenTicket&&!kitchenTicket.sent)||!valid||!!addContext;
 byId('send-kitchen').disabled=busy||!cart.size||!!pending||!!kitchenTicket?.sent;
 byId('send-kitchen').textContent=addContext?(addContext.request?'重試送出加點':'送出加點'):kitchenTicket?.sent?'已送廚房':kitchenTicket?'重試送廚房':'送廚房';
 byId('pay').textContent=pending?'重試記錄收款':'記錄收款並結帳';byId('cancel-addon').hidden=!addContext;byId('cancel-addon').disabled=busy||!!addContext?.request;
 byId('return-ticket').hidden=!kitchenTicket?.sent||!!pending;byId('return-ticket').disabled=busy;
 for(const field of [form.elements.service,form.elements.table])field.disabled=!!pending||!!kitchenTicket||!!addContext;
 form.elements.payment.disabled=!!pending;
}
function guestPick(dish,existing=null,duplicate=false){
 if(!dish)return;
 if(guestSending||guestFrozen||!guestSession?.active||soldOut(dish))return;
 selectVariant(dish,duplicate?{...existing,line_id:uniqueId(),qty:1}:existing,row=>{
  guestVariants=upsertVariant(guestVariants,row,duplicate?null:existing?.line_id);
  syncGuestVariants();saveGuestDraft();renderGuestDishes();renderGuestBasket();
 });
}
function renderGuestDishes(){
 const grid=byId('guest-order-dishes');grid.replaceChildren();
 for(const dish of guestMenu.filter(x=>guestCategory==='全部'||x.category===guestCategory)){
  const card=node('article',undefined,'panel guest-card');const photo=picture(dish);if(photo)card.append(photo);
  card.append(node('small',dish.category),node('h3',dish.name),node('strong',money(dish.price)+(soldOut(dish)?' · 今日售完':'')));
  const control=button('選擇需求',()=>guestPick(dish));control.disabled=guestSending||!!guestFrozen||!guestSession?.active||soldOut(dish);
  card.append(node('p','已選 '+variantQuantity(guestVariants,dish.id)+' 份'),control);grid.append(card);
 }
}
function renderGuestBasket(){
 const list=byId('guest-basket');list.replaceChildren();let total=0;
 for(const x of guestVariants){
  const dish=guestMenu.find(d=>d.id===x.menu_id),price=dish?.price??0;total+=price*x.qty;
  const row=node('article',undefined,'line variant-row');row.append(node('strong',(dish?.name??'已下架餐點')+' × '+x.qty+' · '+money(price*x.qty)),node('p',rowNote(x),'variant-note'));
  if(!guestSending&&!guestFrozen&&guestSession?.active){
   const controls=node('div',undefined,'actions');
   if(dish&&!soldOut(dish))controls.append(button('修改需求',()=>guestPick(dish,x)),button('另加同款',()=>guestPick(dish,x,true)));
   controls.append(button('移除這筆',()=>{guestVariants=guestVariants.filter(v=>v.line_id!==x.line_id);syncGuestVariants();saveGuestDraft();renderGuestDishes();renderGuestBasket();}));row.append(controls);
  }list.append(row);
 }
 byId('guest-total').textContent='預估小計 '+money(total);byId('guest-send').disabled=guestSending||!guestSession?.active||!guestBasket.size;
 byId('guest-send').textContent=guestFrozen?'重試送出原單':'確認送出點餐';byId('guest-note').disabled=guestSending||!!guestFrozen||!guestSession?.active;
 byId('guest-clear').disabled=guestSending||!!guestFrozen;
}
async function enrichSales(sales){
 if(!sales.length)return sales;
 for(let at=0;at<sales.length;at+=500){
  const group=sales.slice(at,at+500);const details=await checked(db.rpc('restaurant_sale_variants',{sale_ids:group.map(x=>x.id)}));
  for(const sale of group){
   const lines=details.find(x=>x.id===sale.id)?.lines;if(!lines)continue;
   sale.original_variant_lines=lines;
   const sums=new Map();for(const x of lines){const key=x.menu_id+':'+x.price;sums.set(key,(sums.get(key)??0)+x.qty);}
   const current=new Map(sale.restaurant_sale_items.map(x=>[x.menu_id+':'+x.unit_price,x.quantity]));
   if(current.size===sums.size&&[...current].every(([k,q])=>sums.get(k)===q))sale.variant_lines=lines;
  }
 }return sales;
}

init();

