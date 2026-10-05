#!/usr/bin/env node
// Regenerate a replayable 8-bar breakdown / 2-bar drum break from saved 159.
// This compiles and queries Tidal OFFLINE; it never boots or plays audio.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {execFileSync} from 'node:child_process';
const root=fileURLToPath(new URL('../',import.meta.url));
const plugin=process.env.PI_TIDAL_DIR ?? path.join(os.homedir(),'pi-tidal');
const {parseScene,patternExpression}=await import(pathToFileURL(path.join(plugin,'lib/scenes.mjs')));
const base=fs.readFileSync(path.join(root,'159.tidal'),'utf8');
const start=0, drums=8, back=10;
const during=(a,b)=>`(\\c -> c >= ${a} && c < ${b})`;
const transform=(pred,fn,pat)=>`whenT ${pred} (${fn}) $ ${pat}`;
const thin=during(start,drums), whole=during(start,back), first=during(start,4), second=during(4,drums), fill=during(drums,back);
const kick='s "<[p70kick ~ ~ p70kick ~ ~ p70kick ~ p70kick ~ ~ ~ p70kick ~ ~ ~] [p70kick ~ ~ ~ ~ p70kick ~ ~ p70kick ~ ~ p70kick ~ ~ p70kick ~]>" # orbit 0 # gain 0.92 # speed 0.94 # lpf 3200 # verbSend 0 # ddSend 0';
const snare='s "<[~ ~ p70snare ~ ~ p70soft ~ p70snare ~ ~ p70soft ~ ~ p70snare ~ ~] [~ ~ p70snare ~ ~ ~ p70snare ~ ~ p70soft p70snare p70snare ~ p70snare p70snare p70snare]>" # orbit 1 # gain "0.68 0.44 0.72 0.38" # speed "0.9 0.96 0.88 1" # nudge 0.012 # hpf 180 # lpf 4800 # verbSend "0 0 0.10 0" # room 0 # verbT60 0.65 # ddSend "0 0 0.12 0" # lock 1 # delaytime 0.125 # delayfeedback 0.24';
const sparseHat='s "~ p70hat ~ p70hat" # orbit 2 # gain 0.12 # speed 0.94 # hpf 2400 # lpf 4400 # verbSend 0 # ddSend 0';
const original=parseScene(base);
if(!base.includes('[4800 + (breath * 650), 0.12, 0.10, 0.95];')) {
  throw Error('159 modulation changed; review the arrangement generator before rebuilding');
}
let text=base.replace(/-- @scene .*\n/,`-- @scene ${JSON.stringify({title:'Window Seat — Breakdown & Breaks',cps:original.cps,quantize:1})}\n`)
  .replace('[4800 + (breath * 650), 0.12, 0.10, 0.95];',
    `var breakdown = (cycles >= 0) * (cycles < 8);\n    var fill = (cycles >= 8) * (cycles < 10);\n    var lift = (cycles / 8).clip(0, 1);\n    [Select.kr(breakdown, [4800 + breath * 650, 1700 + lift * 1300]), 0.12 + fill * 0.025, Select.kr(breakdown, [0.10, 0.15]), 0.95];`)
  .replace('-- Load with /tidal scene load A 159.tidal. Restart explicitly to return to zero.',
    '-- Load/restart this arrangement to perform it from local bar zero.');
text=text.replace(/^d([1-7]) \$ (.*)$/gm,(_,n,pat)=>{
 let p=pat;
 if(n==='1') p=transform(fill,`const (${kick})`,transform(thin,'const silence',p));
 if(n==='2') p=transform(fill,`const (${snare})`,transform(thin,'const silence',p));
 if(n==='3') p=transform(second,'(# gain 0.15)',transform(first,`const (${sparseHat})`,p));
 if(n==='4') p=transform(whole,'const silence',p);
 if(n==='5') p=transform(during(4,back),'(# gain 0.28)',transform(first,'const silence',p));
 if(n==='6') p=transform(whole,'(# gain 0.68) . (# cutoff 2400)',p);
 if(n==='7') p=transform(fill,'const silence',transform(second,'(# gain 0.45)',transform(first,'const silence',p)));
 return `d${n} $ ${p}`;
});
text=`-- Arrangement of 159: bars 0–3 airy keys; 4–7 bass/hats build; 8–9 chopped drums; 10+ full saved groove.\n-- Rebuild offline: node tools/build_window_seat_breakdown.mjs\n`+text;
const scene=parseScene(text);
const params=[...fs.readFileSync(path.join(root,'BootTidal.hs'),'utf8').matchAll(/([a-z][\w']*)\s*=\s*(p[FSI])\s*"([^"\n]+)"/g)].map(m=>`${m[1]} = ${m[2]} "${m[3]}"`);
const bindings=[...new Set(params)].join('; ');
const candidate=patternExpression(scene,'A'), baseline=patternExpression(original,'A');
const hs=`{-# LANGUAGE OverloadedStrings #-}\nimport Sound.Tidal.Context\nimport Control.Monad (unless)\nimport Data.List (sort)\ndefault (Rational,Integer,Double,Pattern String)\nmain = do\n  let candidate = (let { ${bindings} } in ${candidate})\n  let baseline = (let { ${bindings} } in ${baseline})\n  print [length (queryArc candidate (Arc (fromIntegral t) (fromIntegral (t+1)))) | t <- [0,4,8,9,10]]\n  let played pat t = sort [show (whole e, value e) | e <- queryArc pat (Arc (fromIntegral t) (fromIntegral (t+1))), maybe False (\\w -> start w == start (part e)) (whole e)]\n  unless (all (\\t -> played candidate t == played baseline t) [10..17]) (error "return differs from saved groove")\n  putStrLn "PASS: arrangement compiles and bars 10+ play the saved groove's exact onsets/parameters"\n`;
const tmp=fs.mkdtempSync(path.join(os.tmpdir(),'window-seat-arrangement-'));
try {
 const test=path.join(tmp,'check.hs'); fs.writeFileSync(test,hs);
 console.log(execFileSync('runghc',[test],{encoding:'utf8',timeout:20000}));
} catch (error) {
 const concise=String(error.stderr ?? error.message).split('\n').filter(line=>line.length<300).slice(0,20).join('\n');
 throw Error(`Offline Tidal validation failed:\n${concise}`);
} finally { fs.rmSync(tmp,{recursive:true,force:true}); }
const output=path.join(root,'arrangements','159-breakdown.tidal');
fs.mkdirSync(path.dirname(output),{recursive:true});
fs.writeFileSync(output,text);
console.log(`Saved ${output}`);
