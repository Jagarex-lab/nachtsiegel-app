'use strict';
// Structural JSON equality, not JS FNV/JSON.stringify replay hashing (P11).
function canonical(value){
  if(value===null||typeof value==='boolean'||typeof value==='string')return value;
  if(typeof value==='number'){
    if(!Number.isFinite(value)||Math.abs(value)>Number.MAX_SAFE_INTEGER)throw Error('Unsupported JSON number');
    return Object.is(value,-0)?0:value;
  }
  if(Array.isArray(value))return value.map(canonical);
  if(value&&typeof value==='object'&&[Object.prototype,null].includes(Object.getPrototypeOf(value))){
    return Object.fromEntries(Object.keys(value).sort().map(k=>[k,canonical(value[k])]));
  }
  throw Error('Unsupported non-JSON value');
}
function pointer(key){return String(key).replaceAll('~','~0').replaceAll('/','~1');}
function difference(expected,actual,at='$'){
  const e=canonical(expected),a=canonical(actual);
  function walk(x,y,p){
    const type=v=>v===null?'null':Array.isArray(v)?'array':typeof v;
    if(type(x)!==type(y))return {path:p,reason:'type',expected:x,actual:y};
    if(Array.isArray(x)){
      if(x.length!==y.length)return {path:p,reason:'array_length',expected:x.length,actual:y.length};
      for(let i=0;i<x.length;i++){const d=walk(x[i],y[i],p+'/'+i);if(d)return d;}
    }else if(x!==null&&typeof x==='object'){
      for(const k of [...new Set([...Object.keys(x),...Object.keys(y)])].sort()){
        if(!Object.hasOwn(x,k)||!Object.hasOwn(y,k))return {path:p+'/'+pointer(k),reason:'missing_or_extra_field'};
        const d=walk(x[k],y[k],p+'/'+pointer(k));if(d)return d;
      }
    }else if(x!==y)return {path:p,reason:'value',expected:x,actual:y};
    return null;
  }
  return walk(e,a,at);
}
module.exports={canonical,difference};
