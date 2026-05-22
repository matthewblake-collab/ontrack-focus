'use client'

import { useMemo, useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import { useModalA11y } from '../_lib/useModalA11y'
import {
  ResponsiveContainer,
  BarChart, Bar,
  LineChart, Line,
  XAxis, YAxis, Tooltip, CartesianGrid,
} from 'recharts'
import type {
  ActiveProtocol,
  BloodMarkerRecord,
  JournalRecord,
  BodyMetricRecord,
  HealthMetricRecord,
  DailyCheckinRecord,
} from '../protocols/page'

type TabKey = 'overview' | 'bloodwork' | 'hormones' | 'physical' | 'journal' | 'add'

const TABS: { key: TabKey; label: string }[] = [
  { key: 'overview',  label: 'Overview' },
  { key: 'bloodwork', label: 'Bloodwork' },
  { key: 'hormones',  label: 'Hormones' },
  { key: 'physical',  label: 'Physical' },
  { key: 'journal',   label: 'Journal' },
  { key: 'add',       label: 'Add Data' },
]

type MarkerMeta = {
  name: string
  unit: string
  refLow: number
  refHigh: number
  note: { ok: string; warn: string; flag: string }
  invertHigh?: boolean // markers where high = bad (most). True by default.
}

const MARKER_META: Record<string, MarkerMeta> = {
  total_t:     { name: 'Total Testosterone',  unit: 'nmol/L', refLow: 8.3, refHigh: 29,   note: { ok: 'In optimal range', warn: 'Below optimal', flag: 'Above range' } },
  free_t:      { name: 'Free Testosterone',   unit: 'pmol/L', refLow: 255, refHigh: 725,  note: { ok: 'Good free T', warn: 'Suboptimal', flag: 'Above range' } },
  e2:          { name: 'E2 (Oestradiol)',     unit: 'pmol/L', refLow: 0,   refHigh: 150,  note: { ok: 'Well managed', warn: 'Approaching limit', flag: 'Above range — monitor' } },
  lh:          { name: 'LH',                  unit: 'IU/L',   refLow: 0,   refHigh: 7,    note: { ok: 'Suppressed (expected on TRT)', warn: 'Borderline', flag: 'Above range — HPG active' } },
  fsh:         { name: 'FSH',                 unit: 'IU/L',   refLow: 0,   refHigh: 7,    note: { ok: 'Suppressed (expected on TRT)', warn: 'Borderline', flag: 'Above range' } },
  prolactin:   { name: 'Prolactin',           unit: 'mIU/L',  refLow: 40,  refHigh: 450,  note: { ok: 'Within range', warn: 'Elevated — watch', flag: 'Above range' } },
  igf1:        { name: 'IGF-1',               unit: 'nmol/L', refLow: 12,  refHigh: 34,   note: { ok: 'Stable', warn: 'Approaching limit', flag: 'Elevated — monitor' } },
  shbg:        { name: 'SHBG',                unit: 'nmol/L', refLow: 11,  refHigh: 71,   note: { ok: 'Good — more free T', warn: 'Watch', flag: 'High — binds free T' } },
  psa:         { name: 'PSA',                 unit: 'µg/L',   refLow: 0.25, refHigh: 2.2, note: { ok: 'Safe range', warn: 'Watch', flag: 'Elevated — review' } },
  creatinine:  { name: 'Creatinine',          unit: 'µmol/L', refLow: 60,  refHigh: 110,  note: { ok: 'Normal', warn: 'Slightly elevated — monitor', flag: 'Above range — renal watch' } },
  egfr:        { name: 'eGFR',                unit: 'mL/min', refLow: 60,  refHigh: 120,  note: { ok: 'Good filtration', warn: 'Slightly reduced', flag: 'Reduced — monitor renal' } },
  haematocrit: { name: 'Haematocrit',         unit: 'L/L',    refLow: 0.40, refHigh: 0.54, note: { ok: 'Normal', warn: 'Watch — TRT raises this', flag: 'Elevated — phlebotomy risk' } },
  glucose:     { name: 'Fasting Glucose',     unit: 'mmol/L', refLow: 3.4, refHigh: 5.4,  note: { ok: 'Normal', warn: 'Borderline', flag: 'Elevated — action needed' } },
  hba1c:       { name: 'HbA1c',               unit: '%',      refLow: 4.0, refHigh: 6.0,  note: { ok: 'Excellent', warn: 'Watch', flag: 'Elevated' } },
  total_chol:  { name: 'Total Cholesterol',   unit: 'mmol/L', refLow: 3.9, refHigh: 5.2,  note: { ok: 'Normal', warn: 'Borderline', flag: 'Elevated' } },
  ldl:         { name: 'LDL',                 unit: 'mmol/L', refLow: 1.5, refHigh: 3.4,  note: { ok: 'Normal', warn: 'Watch lipids on TRT', flag: 'Elevated' } },
  hdl:         { name: 'HDL',                 unit: 'mmol/L', refLow: 1.0, refHigh: 2.0,  note: { ok: 'Good cardio protection', warn: 'Low-ish', flag: 'Low — watch' } },
  crp:         { name: 'hsCRP',               unit: 'mg/L',   refLow: 0,   refHigh: 4,    note: { ok: 'Low risk', warn: 'Average risk', flag: 'High risk' } },
  gh:          { name: 'GH (random)',         unit: 'mIU/L',  refLow: 0,   refHigh: 3.1,  note: { ok: 'Normal', warn: 'Elevated — use IGF-1', flag: 'Elevated — use IGF-1' } },
}

const MARKER_ORDER = [
  'total_t', 'free_t', 'e2', 'lh', 'fsh', 'prolactin', 'igf1', 'shbg', 'psa',
  'creatinine', 'egfr', 'haematocrit', 'glucose', 'hba1c', 'total_chol', 'ldl', 'hdl', 'crp', 'gh',
]

type MarkerStatus = 'ok' | 'warn' | 'flag'
function statusFor(value: number, refHigh: number): MarkerStatus {
  if (value > refHigh) return 'flag'
  if (value > refHigh * 0.92) return 'warn'
  return 'ok'
}

function weekFromStart(startDate: string | null): number {
  if (!startDate) return 1
  const start = new Date(startDate + (startDate.includes('T') ? '' : 'T00:00:00Z'))
  if (isNaN(start.getTime())) return 1
  const wks = Math.floor((Date.now() - start.getTime()) / (7 * 24 * 60 * 60 * 1000)) + 1
  return Math.max(1, Math.min(26, wks))
}

const PHASES = [
  { idx: 0, wkStart: 1,  wkEnd: 4,  icon: '🚀', label: 'Titration',     sub: 'Body adjusting to exogenous testosterone — axes still fluctuating',
    expect: [
      { c: '#f5a623', t: 'Energy peaks & crashes track injection schedule. T spikes then troughs — completely normal.' },
      { c: '#f472b6', t: 'Libido spike common first 1–2 weeks, may dip before stabilising around week 6.' },
      { c: '#f06b4b', t: 'Mood variability — highs 1–2 days post-inject, flat near trough.' },
      { c: '#a78bfa', t: 'Water retention — E2 already elevated. Watch face / fingers / ankles.' },
      { c: '#4f8ef7', t: 'Injection site PIP — mild soreness normal. Warm oil, inject slowly.' },
      { c: '#2dd4a0', t: 'Testicular volume begins decreasing as LH / FSH suppression starts.' },
    ],
    actions: [
      { c: '#2dd4a0', t: '29g 12mm SubQ or 29g 16mm IM minimum. Warm oil. Slow inject.' },
      { c: '#f5a623', t: 'Zinc 40mg daily — glycinate form with food. E2 support.' },
      { c: '#a78bfa', t: 'No new prescription compounds — clean baseline.' },
      { c: '#4f8ef7', t: 'Log daily: energy 1–10, sleep, mood, libido, injection notes.' },
      { c: '#4ade80', t: 'Book Week 6–8 blood draw — trough timing.' },
    ],
  },
  { idx: 1, wkStart: 5,  wkEnd: 8,  icon: '🔬', label: 'First Bloods',  sub: 'First on-TRT panel — confirm T levels, E2, LH / FSH suppression',
    expect: [
      { c: '#2dd4a0', t: 'Total T rising — expect 25–40+ nmol/L if dose dialled in.' },
      { c: '#f5a623', t: 'E2 may still be elevated — aromatisation increases with T dose.' },
      { c: '#a78bfa', t: 'LH / FSH suppressing — should trend toward near-zero.' },
      { c: '#4ade80', t: 'Energy stabilising — once steady-state ~4–6 wks variability reduces.' },
      { c: '#4f8ef7', t: 'Sleep quality improving — testosterone directly affects sleep architecture.' },
      { c: '#f472b6', t: 'First gym improvements — pump, recovery, session capacity noticeably better.' },
    ],
    actions: [
      { c: '#f06b4b', t: 'Draw at trough — morning of or day before injection.' },
      { c: '#4f8ef7', t: 'Request: Total T, Free T, SHBG, E2, LH, FSH, PRL, PSA, FBE, CMP, lipids, IGF-1.' },
      { c: '#f5a623', t: 'E2 decision — if still >150, discuss DIM or AI with doctor.' },
      { c: '#2dd4a0', t: 'GH-axis compound? Only if IGF-1, glucose, renal all clean.' },
    ],
  },
  { idx: 2, wkStart: 9,  wkEnd: 12, icon: '⚡', label: 'Adaptation',    sub: 'Levels plateauing — first visible changes, stack decisions',
    expect: [
      { c: '#2dd4a0', t: 'Stable energy baseline — less inter-injection variability.' },
      { c: '#4ade80', t: 'Body recomposition starts — fat redistribution, protein synthesis increasing.' },
      { c: '#f472b6', t: 'Libido steady and improved — if E2 managed.' },
      { c: '#4f8ef7', t: 'Cognitive clarity — brain fog lifts, focus improves around wks 8–12.' },
      { c: '#f5a623', t: 'Acne possible — back / shoulders most common. Zinc helps.' },
      { c: '#a78bfa', t: 'Haematocrit rising — TRT stimulates RBC production. Monitor.' },
    ],
    actions: [
      { c: '#f5a623', t: 'Stack review with doctor — reassess any paused compounds if bloods clean.' },
      { c: '#2dd4a0', t: 'Progressive overload now safe — recovery capacity significantly enhanced.' },
      { c: '#f06b4b', t: 'If haematocrit >50–52% — discuss phlebotomy or dose reduction.' },
      { c: '#4f8ef7', t: 'Sleep hygiene critical — TRT amplifies recovery but doesn\'t replace it.' },
    ],
  },
  { idx: 3, wkStart: 13, wkEnd: 18, icon: '💪', label: 'Peak Window',   sub: 'Optimal hormonal environment — visible changes, strength, cognition',
    expect: [
      { c: '#4ade80', t: 'Measurable strength gains — consistent PRs across all compound lifts.' },
      { c: '#2dd4a0', t: 'Visible muscle fullness — muscle bellies fuller at rest. Improved ratio.' },
      { c: '#4f8ef7', t: 'Vascularity increasing — forearms, shoulders, biceps more prominent.' },
      { c: '#f5a623', t: 'Fat loss accelerating — particularly visceral.' },
      { c: '#a78bfa', t: 'Confidence and drive — neurological effects on motivation are real.' },
      { c: '#f472b6', t: 'Skin may be oilier — depending on E2 / T ratio.' },
    ],
    actions: [
      { c: '#f06b4b', t: 'Mid-point panel at wk 16–18 — full bloods. E2, haematocrit, renal, PSA, lipids.' },
      { c: '#a78bfa', t: 'DEXA scan optional — objective lean / fat baseline at 4-month mark.' },
      { c: '#4f8ef7', t: 'Supplement audit — reassess zinc, glutathione, creatine based on bloods.' },
    ],
  },
  { idx: 4, wkStart: 19, wkEnd: 22, icon: '🧪', label: 'Re-Eval',       sub: 'Adjust, optimise, confirm long-term protocol viability',
    expect: [
      { c: '#2dd4a0', t: 'Stable plateau — the initial boost is gone. This is your new normal.' },
      { c: '#4ade80', t: 'Sustained muscle mass — maintenance easier, less protein needed to hold.' },
      { c: '#4f8ef7', t: 'Natural T fully suppressed — HPG axis near-zero LH / FSH expected.' },
      { c: '#f5a623', t: 'Libido consistent — if E2 well managed, reliably good with minimal variability.' },
    ],
    actions: [
      { c: '#f06b4b', t: 'Comprehensive panel — full hormonal, metabolic, renal, lipid, FBE.' },
      { c: '#a78bfa', t: 'Injection frequency review — weekly vs bi-weekly based on SHBG and T peaks.' },
      { c: '#4f8ef7', t: 'Fertility planning — if relevant, discuss HCG or sperm banking.' },
    ],
  },
  { idx: 5, wkStart: 23, wkEnd: 26, icon: '🏆', label: '6-Month Mark',  sub: 'Full protocol review — compare where you are to where you started',
    expect: [
      { c: '#4ade80', t: 'Body composition delta — typical TRT + training: 2–5kg lean mass, 2–4% fat reduction.' },
      { c: '#2dd4a0', t: 'Hormonal stability — levels predictable and consistent. New baseline set.' },
      { c: '#f5a623', t: 'Psychological adaptation — euphoria long gone. Benefits feel like "you". Correct.' },
      { c: '#a78bfa', t: 'Long-term commitment clarity — TRT is typically lifelong. Confirm alignment.' },
    ],
    actions: [
      { c: '#f06b4b', t: 'Full 6-month review — comprehensive panel + consult. Adjust dose, frequency.' },
      { c: '#2dd4a0', t: 'Compare all panels: baseline → first bloods → wk 16 → wk 26.' },
      { c: '#4f8ef7', t: 'Document what worked — protocol wins, supplement responses, technique notes.' },
      { c: '#4ade80', t: 'Set Year 1 goals — stack strategy, body composition targets.' },
    ],
  },
]

type HormoneEdu = {
  id: string
  icon: string
  color: string
  bg: string
  title: string
  unit: string
  what: string
  trt: string
}

const HORMONES: HormoneEdu[] = [
  { id: 'total_t', icon: '⚗️', color: '#2dd4a0', bg: 'rgba(45,212,160,.1)',  title: 'Total Testosterone',     unit: 'nmol/L · Ref 8.3–29',
    what: 'Total amount of testosterone in blood — both free (active) and bound (to SHBG and albumin). Produced in testes via LH stimulation. Controls muscle protein synthesis, RBC production, bone density, libido, mood, and drive.',
    trt:  'On TRT, Total T rises significantly. Goal is not just "in range" but optimal — most men feel best 20–30 nmol/L. Expect this to climb once titration is complete.' },
  { id: 'free_t', icon: '🔓', color: '#4ade80', bg: 'rgba(74,222,128,.1)', title: 'Free Testosterone',      unit: 'pmol/L · Ref 255–725',
    what: 'The unbound, bioavailable fraction (~2–3%) that can enter cells and activate androgen receptors. SHBG binds testosterone tightly making it inactive — lower SHBG means more free T.',
    trt:  'TRT commonly lowers SHBG, increasing free T%. Watching free T alongside total T is more informative than total alone.' },
  { id: 'e2', icon: '🌸', color: '#f472b6', bg: 'rgba(244,114,182,.1)', title: 'Oestradiol (E2)', unit: 'pmol/L · Male ref <150',
    what: 'Primary oestrogen in males, produced by aromatase converting testosterone to oestradiol. Essential for bone density, joint health, libido, cardiovascular function. Too high causes water retention, gyno, mood swings, and ED.',
    trt:  'TRT increases aromatase activity proportionally with dose. Zinc inhibits aromatase mildly. Target for most TRT men is 70–130 pmol/L. AI (anastrozole) or DIM are options if needed.' },
  { id: 'lh', icon: '🧬', color: '#f5a623', bg: 'rgba(245,166,35,.1)', title: 'LH (Luteinising Hormone)', unit: 'IU/L · Ref <7',
    what: 'Released by the pituitary to signal testes to produce testosterone via Leydig cells. In untreated males, LH rises when T drops (feedback loop). Elevated LH at baseline means testes are being driven hard but struggling.',
    trt:  'Exogenous testosterone suppresses the HPG axis — pituitary detects high T and stops sending LH. Should drop to near-zero on TRT. Will suppress over weeks 6–12.' },
  { id: 'fsh', icon: '🔵', color: '#a78bfa', bg: 'rgba(167,139,250,.1)', title: 'FSH', unit: 'IU/L · Ref <7',
    what: 'Pituitary-released, stimulates sperm production in testicular Sertoli cells. Part of HPG feedback loop. Suppression on TRT leads to reduced sperm count and potential fertility impact.',
    trt:  'TRT suppresses FSH toward zero over weeks 6–12. If fertility matters, HCG can be added to maintain testicular function.' },
  { id: 'prolactin', icon: '💧', color: '#4f8ef7', bg: 'rgba(79,142,247,.1)', title: 'Prolactin', unit: 'mIU/L · Ref 40–450',
    what: 'Produced by the pituitary. Elevated prolactin (hyperprolactinaemia) suppresses LH / FSH, causing low libido, ED, and mood issues.',
    trt:  'Stimulant supplements are a documented confounding factor. Cabergoline is the prescription option if genuinely elevated.' },
  { id: 'igf1', icon: '📈', color: '#2dd4a0', bg: 'rgba(45,212,160,.08)', title: 'IGF-1', unit: 'nmol/L · Ref 12–34',
    what: 'Produced by the liver in response to GH. IGF-1 is the downstream mediator of GH\'s anabolic effects — muscle protein synthesis, fat mobilisation, bone formation. Unlike pulsatile GH, IGF-1 is stable in blood making it the preferred GH-axis marker.',
    trt:  'TRT mildly raises IGF-1. GH-axis compounds significantly raise it. Monitor closely.' },
  { id: 'shbg', icon: '🔗', color: '#f06b4b', bg: 'rgba(240,107,75,.1)', title: 'SHBG', unit: 'nmol/L · Ref 11–71',
    what: 'Sex Hormone Binding Globulin — protein that binds testosterone tightly, rendering it biologically inactive. High SHBG = less free T even with normal total T.',
    trt:  'TRT typically lowers SHBG over time. Lower SHBG means injections need more frequency to maintain stable levels (faster clearance).' },
  { id: 'psa', icon: '🔬', color: '#4f8ef7', bg: 'rgba(79,142,247,.08)', title: 'PSA', unit: 'µg/L · Ref 0.25–2.20',
    what: 'Prostate-Specific Antigen — produced by prostate cells, used as a screening marker for prostate health. Serial monitoring is more important than single values.',
    trt:  'TRT can mildly raise PSA. Must monitor every 6–12 months. A jump >0.75 in 12 months or value exceeding 2.0 warrants urology review.' },
  { id: 'haematocrit', icon: '🩸', color: '#f87171', bg: 'rgba(248,113,113,.1)', title: 'Haematocrit', unit: 'L/L · Ref 0.40–0.54',
    what: 'Proportion of blood volume made up by red blood cells. High haematocrit = thicker blood, increasing clot, stroke, and CV risk. Testosterone stimulates EPO production driving RBC production.',
    trt:  'Critical TRT safety marker. Above 0.52 is typically the threshold for therapeutic phlebotomy or dose reduction. Monitor every 3–4 months. Stay hydrated.' },
  { id: 'creatinine', icon: '🫘', color: '#f87171', bg: 'rgba(248,113,113,.08)', title: 'Creatinine / eGFR', unit: 'µmol/L · Ref 60–110',
    what: 'Creatinine is waste from muscle metabolism filtered by kidneys. eGFR estimates kidney filtering efficiency. Rising creatinine / falling eGFR signals kidney stress. Creatine supplementation mildly raises creatinine non-pathologically.',
    trt:  'TRT increases muscle mass which raises creatinine. Trend needs watching — ensure adequate hydration.' },
]

type PhysItem = { c: string; text: string; intensity?: 'mild' | 'mod' | 'strong' }
type PhysSection = { wk: string; wkStart: number; wkEnd: number; items: PhysItem[] }
type PhysTab = { key: string; label: string; sections: PhysSection[] }

const PHYS: PhysTab[] = [
  { key: 'muscle', label: '💪 Muscle', sections: [
    { wk: 'Wk 1–4',   wkStart: 1,  wkEnd: 4,  items: [
      { c: '#4f8ef7', intensity: 'mild',   text: 'Better pump during training — increased intracellular water and nitrogen retention. Not lean mass yet, but noticeable fullness.' },
      { c: '#2dd4a0', intensity: 'mild',   text: 'Recovery speed improves — DOMS shortens, more volume per week becomes manageable.' },
      { c: '#a78bfa',                      text: 'Glycogen storage increases — muscles feel harder and fuller even without extra training.' },
    ]},
    { wk: 'Wk 5–8',   wkStart: 5,  wkEnd: 8,  items: [
      { c: '#4ade80', intensity: 'mod',    text: 'Visible size increase begins — lean mass accrual measurable. Scale may rise 1–2kg.' },
      { c: '#2dd4a0',                      text: 'Muscle hardness at rest — bellies denser, harder appearance and feel vs pre-TRT.' },
      { c: '#f5a623',                      text: 'Training volume capacity up 20–30% — more sets per session, faster recovery.' },
    ]},
    { wk: 'Wk 9–14',  wkStart: 9,  wkEnd: 14, items: [
      { c: '#4ade80', intensity: 'strong', text: 'Consistent lean mass accumulation — 0.5–1.5kg per month realistic with progressive training and ≥1.8g/kg protein.' },
      { c: '#f472b6',                      text: 'Muscle fullness 24/7 — shoulders, chest, arms visibly fuller even at rest in clothing.' },
      { c: '#4f8ef7',                      text: 'Satellite cell activation — testosterone promotes muscle stem cell activity: new fibres, not just hypertrophy.' },
    ]},
    { wk: 'Wk 15–26', wkStart: 15, wkEnd: 26, items: [
      { c: '#2dd4a0', intensity: 'strong', text: '2–5kg lean mass realistic at 6 months — gradual accrual with consistent training.' },
      { c: '#f5a623',                      text: 'Anti-catabolic effect — muscle preserved even during caloric deficit phases.' },
      { c: '#4ade80',                      text: 'Muscle setpoint rises — TRT raises your genetic ceiling. Gains are maintainable long-term.' },
    ]},
  ]},
  { key: 'fat', label: '🔥 Fat', sections: [
    { wk: 'Wk 1–6',   wkStart: 1,  wkEnd: 6,  items: [
      { c: '#f5a623', intensity: 'mild',   text: 'Minimal change initially — fat loss is not an early TRT effect. Body recomposition is the mechanism.' },
      { c: '#f06b4b',                      text: 'E2 elevation may cause water retention — temporary bloating, not true fat.' },
      { c: '#a78bfa',                      text: 'Visceral fat mobilisation begins — testosterone targets visceral adipose via androgen receptor activation in fat cells.' },
    ]},
    { wk: 'Wk 7–14',  wkStart: 7,  wkEnd: 14, items: [
      { c: '#f5a623', intensity: 'mod',    text: 'Visible waist reduction — visceral fat reduction shows first around waistline. Belt notch improvement.' },
      { c: '#f06b4b',                      text: 'Subcutaneous fat becomes more metabolically active — responds better to caloric deficit.' },
      { c: '#2dd4a0',                      text: 'Combined with cardio + diet, this phase delivers visible composition change.' },
    ]},
    { wk: 'Wk 15–26', wkStart: 15, wkEnd: 26, items: [
      { c: '#f5a623', intensity: 'strong', text: '2–4% body fat reduction realistic at 6 months — amplified with consistent cardio + nutrition.' },
      { c: '#4ade80',                      text: 'Improved body composition ratio — even if scale weight changes little, muscle:fat ratio measurably improves.' },
      { c: '#f06b4b',                      text: 'Visceral fat reduces independently of caloric restriction with hormonal optimisation.' },
    ]},
  ]},
  { key: 'vascular', label: '🩸 Vascularity', sections: [
    { wk: 'Wk 1–6',   wkStart: 1,  wkEnd: 6,  items: [
      { c: '#f87171', intensity: 'mild', text: 'Pump vascularity — increased blood volume (haematocrit rising) makes veins more visible during exercise.' },
      { c: '#f06b4b',                    text: 'Resting vascularity unchanged — first 4–6 weeks are mostly intracellular changes. No forearm veins at rest yet.' },
      { c: '#a78bfa',                    text: 'Nitric oxide production increases — better blood flow and pump.' },
    ]},
    { wk: 'Wk 7–14',  wkStart: 7,  wkEnd: 14, items: [
      { c: '#f87171', intensity: 'mod',  text: 'Forearm vascularity at rest starts — as subcutaneous fat drops and muscle density increases, forearm and bicep veins visible.' },
      { c: '#f5a623',                    text: 'Shoulder vascularity improves — delt veins visible during training, persist longer post-workout.' },
      { c: '#4f8ef7',                    text: 'Skin thinning over muscles — subcutaneous fat reduces over trained muscle groups, improving vascularity.' },
    ]},
    { wk: 'Wk 15–26', wkStart: 15, wkEnd: 26, items: [
      { c: '#f87171', intensity: 'strong', text: 'Significant visible vascularity — forearms, biceps, shoulders prominent. Quad vascularity visible at lower body fat %.' },
      { c: '#f06b4b',                      text: 'Monitor haematocrit — high haematocrit contributes to vascularity but >52% raises clot risk. Stay hydrated.' },
    ]},
  ]},
  { key: 'skin', label: '👁 Skin & Hair', sections: [
    { wk: 'Wk 1–6',   wkStart: 1,  wkEnd: 6,  items: [
      { c: '#f5a623', intensity: 'mild', text: 'Increased sebum production — androgens stimulate sebaceous glands. Skin may feel oilier — face, back, shoulders.' },
      { c: '#f06b4b',                    text: 'Acne risk rises — body acne (back / shoulders) more likely than facial in adults. Zinc 40mg helps via 5-alpha-reductase inhibition.' },
      { c: '#a78bfa',                    text: 'Hair follicle stimulation — body / beard hair growth may increase. Head hair thinning is DHT-mediated and genetic.' },
    ]},
    { wk: 'Wk 7–14',  wkStart: 7,  wkEnd: 14, items: [
      { c: '#4ade80',                    text: 'Collagen synthesis improves — testosterone upregulates collagen gene expression. Skin thicker, more elastic over time.' },
      { c: '#f5a623', intensity: 'mod',  text: 'Acne peaks then stabilises — inflammatory period settles by week 12 if E2 is managed.' },
      { c: '#f06b4b',                    text: 'DHT conversion — 5-alpha-reductase converts T to DHT. Lower risk if no family hair-loss history.' },
    ]},
    { wk: 'Wk 15–26', wkStart: 15, wkEnd: 26, items: [
      { c: '#4ade80', intensity: 'strong', text: 'Skin quality improvement visible — thicker dermis, better hydration, improved tone particularly face and neck.' },
      { c: '#a78bfa',                      text: 'Connective tissue support compounds aid collagen synthesis and tissue regeneration.' },
    ]},
  ]},
  { key: 'strength', label: '🏋️ Strength', sections: [
    { wk: 'Wk 1–4',   wkStart: 1,  wkEnd: 4,  items: [
      { c: '#f5a623', intensity: 'mild', text: 'Neural efficiency improves first — motor unit recruitment improves before muscle grows. PRs come before size.' },
      { c: '#4f8ef7',                    text: '5–10% strength increase realistic in first 4 weeks from neural adaptations alone.' },
      { c: '#2dd4a0',                    text: 'Training aggression improves — push harder, rest shorter.' },
    ]},
    { wk: 'Wk 5–12',  wkStart: 5,  wkEnd: 12, items: [
      { c: '#4ade80', intensity: 'mod',  text: 'Consistent PRs across all main lifts — squat, deadlift, bench, row. Expect 2.5–5kg increases bi-weekly.' },
      { c: '#f06b4b',                    text: 'Connective tissue lags muscle — tendons adapt slower. Don\'t jump weight too fast.' },
      { c: '#f472b6',                    text: 'Grip and forearm strength increase markedly — high density of androgen receptors in forearm.' },
    ]},
    { wk: 'Wk 13–26', wkStart: 13, wkEnd: 26, items: [
      { c: '#4ade80', intensity: 'strong', text: '15–25% total strength increase realistic at 6 months — above pre-TRT baseline with consistent training.' },
      { c: '#2dd4a0',                      text: 'Force production at fatigue improves — maintain form and power longer into sets.' },
      { c: '#a78bfa',                      text: 'Joint integrity matters — connective tissue base supports added strength loads safely.' },
    ]},
  ]},
  { key: 'libido', label: '⚡ Libido', sections: [
    { wk: 'Wk 1–3',   wkStart: 1,  wkEnd: 3,  items: [
      { c: '#f472b6', intensity: 'strong', text: 'Libido spike — often dramatic. Initial T surge causes noticeable libido increase in first 1–3 weeks.' },
      { c: '#f06b4b',                      text: 'Erection quality variable — E2 management is the #1 lever for this.' },
      { c: '#4f8ef7',                      text: 'Morning erections return — loss of morning erections is a classic low-T symptom. Return within weeks 1–4.' },
    ]},
    { wk: 'Wk 4–12',  wkStart: 4,  wkEnd: 12, items: [
      { c: '#f472b6', intensity: 'mod',    text: 'Libido normalises and stabilises — settles at consistently higher baseline than pre-TRT if E2 is managed.' },
      { c: '#f06b4b',                      text: 'Erection quality tied to E2 — if E2 stays elevated >150 pmol/L, quality can be blunted.' },
      { c: '#4ade80',                      text: 'Ejaculatory volume may decrease — FSH / LH suppression reduces seminal fluid production. Normal on TRT.' },
    ]},
    { wk: 'Wk 13–26', wkStart: 13, wkEnd: 26, items: [
      { c: '#f472b6', intensity: 'strong', text: 'Sustained libido improvement — consistently above pre-TRT baseline once optimised.' },
      { c: '#a78bfa',                      text: 'Testicular atrophy — significant by 3–6 months as LH / FSH approach zero. HCG reverses this if desired.' },
      { c: '#4f8ef7',                      text: 'Overall sexual wellbeing — satisfaction, confidence, and function broadly improved in majority of TRT responders by month 4–6.' },
    ]},
  ]},
  { key: 'mental', label: '🧠 Mental', sections: [
    { wk: 'Wk 1–4',   wkStart: 1,  wkEnd: 4,  items: [
      { c: '#a78bfa', intensity: 'mild', text: 'Mood elevation — often rapid. Many notice improved mood within days. Testosterone modulates serotonin and dopamine directly.' },
      { c: '#4f8ef7',                    text: 'Motivation and drive increase — tasks feel more achievable, procrastination reduces.' },
      { c: '#f5a623',                    text: 'Irritability possible — if E2 is rising rapidly or T peaking high. Track mood vs injection day.' },
    ]},
    { wk: 'Wk 5–12',  wkStart: 5,  wkEnd: 12, items: [
      { c: '#a78bfa', intensity: 'mod',  text: 'Cognitive clarity improves — brain fog lifts, verbal fluency and working memory improve.' },
      { c: '#4ade80',                    text: 'Competitive drive and confidence — assertiveness increases. Androgenic effects on amygdala and PFC.' },
      { c: '#4f8ef7',                    text: 'Emotional resilience — minor stressors less overwhelming. Cortisol / T ratio improves.' },
    ]},
    { wk: 'Wk 13–26', wkStart: 13, wkEnd: 26, items: [
      { c: '#a78bfa', intensity: 'strong', text: 'Stable, improved baseline mood — consistent sense of wellbeing, purpose, and engagement.' },
      { c: '#4f8ef7',                      text: 'Anti-depressant effects documented — clinical evidence for improving subclinical depression in hypogonadal men.' },
      { c: '#f5a623',                      text: 'Adaptation warning — benefits eventually feel like "you". That\'s correct. Don\'t mistake adaptation for treatment not working.' },
    ]},
  ]},
  { key: 'sleep', label: '😴 Sleep', sections: [
    { wk: 'Wk 1–4',   wkStart: 1,  wkEnd: 4,  items: [
      { c: '#4f8ef7', intensity: 'mild', text: 'Sleep architecture begins improving — testosterone directly affects slow-wave (deep) sleep staging.' },
      { c: '#f5a623',                    text: 'Sleep apnoea warning — TRT can worsen OSA in susceptible individuals. Flag to doctor if snoring increases.' },
      { c: '#a78bfa',                    text: 'Anti-inflammatory support compounds reduce systemic inflammation overnight.' },
    ]},
    { wk: 'Wk 5–14',  wkStart: 5,  wkEnd: 14, items: [
      { c: '#4f8ef7', intensity: 'mod',  text: 'Deep sleep duration increases — Stage 3 slow-wave sleep is where GH is pulsed, muscle repair occurs, memory consolidates.' },
      { c: '#4ade80',                    text: 'Recovery between sessions dramatically better — wake less sore, fresher, can train harder on consecutive days.' },
    ]},
    { wk: 'Wk 15–26', wkStart: 15, wkEnd: 26, items: [
      { c: '#4f8ef7', intensity: 'strong', text: 'Sustained sleep quality improvement — less fragmented, better REM, improved morning wakefulness.' },
      { c: '#4ade80',                      text: 'Recovery capacity vs natural — recovering significantly faster than pre-TRT.' },
      { c: '#a78bfa',                      text: 'Circadian rhythm stabilisation — testosterone plays a role in melatonin regulation and circadian clock gene expression.' },
    ]},
  ]},
]

const TAG_COLORS: Record<string, string> = {
  energy: '#f5a623', mood: '#a78bfa', sleep: '#4f8ef7', injection: '#2dd4a0',
  'side-effect': '#f06b4b', bloodwork: '#f472b6', libido: '#f472b6', gym: '#4ade80', general: '#8892a4',
}
const TAG_OPTIONS = ['energy', 'mood', 'sleep', 'injection', 'side-effect', 'bloodwork', 'libido', 'gym', 'general']

export function ProtocolsClient({
  userId,
  protocol,
  markers,
  journal,
  metrics,
  healthMetrics,
  checkins,
}: {
  userId: string
  protocol: ActiveProtocol | null
  markers: BloodMarkerRecord[]
  journal: JournalRecord[]
  metrics: BodyMetricRecord[]
  healthMetrics: HealthMetricRecord[]
  checkins: DailyCheckinRecord[]
}) {
  const [tab, setTab] = useState<TabKey>('overview')
  const [openPhase, setOpenPhase] = useState<number>(0)
  const router = useRouter()

  const currentWeek = useMemo(() => weekFromStart(protocol?.start_date ?? null), [protocol?.start_date])
  const currentPhaseIdx = useMemo(() => {
    const p = PHASES.find(ph => currentWeek >= ph.wkStart && currentWeek <= ph.wkEnd)
    return p ? p.idx : 0
  }, [currentWeek])

  const grouped = useMemo(() => {
    const m = new Map<string, BloodMarkerRecord[]>()
    for (const row of markers) {
      if (!m.has(row.marker)) m.set(row.marker, [])
      m.get(row.marker)!.push(row)
    }
    Array.from(m.values()).forEach(list => list.sort((a, b) => a.collected_at.localeCompare(b.collected_at)))
    return m
  }, [markers])

  const protocolChips = useMemo(() => {
    const cfg = protocol?.config as Record<string, unknown> | null
    const arr = (cfg?.compounds ?? cfg?.protocol_chips ?? []) as unknown[]
    if (Array.isArray(arr) && arr.length > 0) {
      return arr.map(c => {
        if (typeof c === 'string') return { label: c, color: '#2dd4a0' }
        if (c && typeof c === 'object') {
          const o = c as Record<string, unknown>
          return { label: String(o.label ?? o.name ?? 'Compound'), color: String(o.color ?? '#2dd4a0') }
        }
        return { label: 'Compound', color: '#2dd4a0' }
      })
    }
    if (protocol?.protocol_name) return [{ label: protocol.protocol_name, color: '#2dd4a0' }]
    return []
  }, [protocol])

  const activeFlags = useMemo(() => {
    const out: string[] = []
    for (const key of MARKER_ORDER) {
      const list = grouped.get(key)
      if (!list || list.length === 0) continue
      const latest = list[list.length - 1]
      const meta = MARKER_META[key]
      if (!meta) continue
      const refHigh = latest.reference_high ?? meta.refHigh
      if (latest.value > refHigh) {
        out.push(`${meta.name} ${latest.value} ${meta.unit} (ref <${refHigh})`)
      }
    }
    return out
  }, [grouped])

  return (
    <div className="space-y-4">
      {/* Protocol header */}
      <div className="card flex items-center justify-between gap-3 flex-wrap">
        <div>
          <h2 className="text-lg font-semibold">
            {protocol?.protocol_name ?? 'Protocol'}
          </h2>
          <p className="text-xs text-text-muted mt-1">
            {protocol?.start_date ? `Started ${new Date(protocol.start_date).toLocaleDateString('en-AU', { day: 'numeric', month: 'short', year: 'numeric' })}` : 'No active protocol'}
            {protocol ? ` · Week ${currentWeek} of 26` : ''}
          </p>
        </div>
        {protocol && (
          <span className="text-[11px] px-2.5 py-1 rounded-full" style={{ background: 'rgba(45,212,160,.12)', color: '#2dd4a0', border: '1px solid rgba(45,212,160,.3)' }}>
            Active
          </span>
        )}
      </div>

      {/* Tabs */}
      <div className="flex gap-1 overflow-x-auto border-b border-white/5 -mx-1 px-1">
        {TABS.map(t => (
          <button
            key={t.key}
            onClick={() => setTab(t.key)}
            className={`px-3 py-2 text-xs font-semibold whitespace-nowrap border-b-2 transition-colors ${
              tab === t.key
                ? 'text-accent border-accent'
                : 'text-text-muted border-transparent hover:text-white'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {tab === 'overview' && (
        <OverviewTab
          currentWeek={currentWeek}
          currentPhaseIdx={currentPhaseIdx}
          openPhase={openPhase}
          setOpenPhase={setOpenPhase}
          protocolChips={protocolChips}
          activeFlags={activeFlags}
          checkins={checkins}
        />
      )}
      {tab === 'bloodwork' && (
        <BloodworkTab grouped={grouped} />
      )}
      {tab === 'hormones' && (
        <HormonesTab grouped={grouped} />
      )}
      {tab === 'physical' && (
        <PhysicalTab currentWeek={currentWeek} healthMetrics={healthMetrics} />
      )}
      {tab === 'journal' && (
        <JournalTab
          userId={userId}
          journal={journal}
          protocolId={protocol?.id ?? null}
          protocolStartDate={protocol?.start_date ?? null}
          onSaved={() => router.refresh()}
        />
      )}
      {tab === 'add' && (
        <AddDataTab
          userId={userId}
          recentMetrics={metrics.slice(0, 3)}
          onSaved={() => router.refresh()}
        />
      )}
    </div>
  )
}

function OverviewTab({
  currentWeek, currentPhaseIdx, openPhase, setOpenPhase, protocolChips, activeFlags, checkins,
}: {
  currentWeek: number
  currentPhaseIdx: number
  openPhase: number
  setOpenPhase: (i: number) => void
  protocolChips: { label: string; color: string }[]
  activeFlags: string[]
  checkins: DailyCheckinRecord[]
}) {
  const pct = Math.min(100, Math.round((currentWeek / 26) * 100))
  const phase = PHASES[currentPhaseIdx]
  const detail = openPhase >= 0 ? PHASES[openPhase] : null
  return (
    <div className="space-y-4">
      <div className="card flex items-center gap-4 flex-wrap">
        <div>
          <div className="text-4xl font-extrabold text-accent leading-none">{currentWeek}</div>
          <div className="text-xs text-text-muted mt-1">weeks on protocol</div>
        </div>
        <div className="flex-1 min-w-[180px]">
          <div className="text-sm font-semibold">{phase.label} phase</div>
          <div className="text-xs text-text-muted mt-0.5">Week {currentWeek} of 26</div>
          <div className="h-1.5 rounded mt-2" style={{ background: 'var(--surface-2)' }}>
            <div className="h-full rounded transition-all" style={{ width: `${pct}%`, background: 'linear-gradient(90deg, #2dd4a0, #4f8ef7)' }} />
          </div>
        </div>
      </div>

      {protocolChips.length > 0 && (
        <div className="flex flex-wrap gap-2">
          {protocolChips.map((c, i) => (
            <span key={i} className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-[11px] border" style={{ background: 'var(--surface)', borderColor: 'rgba(255,255,255,.07)' }}>
              <span className="w-1.5 h-1.5 rounded-full" style={{ background: c.color }} />
              {c.label}
            </span>
          ))}
        </div>
      )}

      {activeFlags.length > 0 && (
        <div className="rounded-xl px-4 py-3 text-xs leading-relaxed" style={{ background: 'rgba(245,166,35,.07)', border: '1px solid rgba(245,166,35,.2)', color: '#f5a623' }}>
          <strong>⚡ Active flags:</strong> {activeFlags.join(' · ')}
        </div>
      )}

      <div>
        <div className="text-[10px] font-bold uppercase tracking-widest text-text-muted mb-3">6-Month Timeline</div>
        <div className="grid grid-cols-3 md:grid-cols-6 gap-2">
          {PHASES.map((p, i) => {
            const state = i === currentPhaseIdx ? 'active' : i < currentPhaseIdx ? 'done' : 'locked'
            const ring = state === 'active' ? 'ring-2 ring-accent' : state === 'done' ? 'opacity-100' : 'opacity-50'
            return (
              <button
                key={i}
                onClick={() => setOpenPhase(openPhase === i ? -1 : i)}
                className={`card flex flex-col items-center text-center gap-1 py-3 hover:opacity-95 transition-opacity ${ring} ${openPhase === i ? 'border-accent/50' : ''}`}
              >
                <div className="text-2xl">{p.icon}</div>
                <div className="text-[10px] text-text-muted">Wk {p.wkStart}–{p.wkEnd}</div>
                <div className="text-[11px] font-bold">{p.label}</div>
              </button>
            )
          })}
        </div>
      </div>

      {detail && (
        <div className="card !p-0 overflow-hidden">
          <div className="px-4 py-3 border-b border-white/5 flex items-center gap-3">
            <div className="text-2xl">{detail.icon}</div>
            <div>
              <div className="text-sm font-bold">Week {detail.wkStart}–{detail.wkEnd}: {detail.label}</div>
              <div className="text-[11px] text-text-muted mt-0.5">{detail.sub}</div>
            </div>
          </div>
          <div className="grid md:grid-cols-2 gap-0">
            <div className="p-4 md:border-r border-white/5">
              <div className="text-[10px] font-bold uppercase tracking-wider text-text-muted mb-2">What to expect</div>
              {detail.expect.map((f, i) => (
                <div key={i} className="flex gap-2 items-start mb-2">
                  <span className="w-1.5 h-1.5 rounded-full mt-1.5 flex-shrink-0" style={{ background: f.c }} />
                  <p className="text-xs leading-relaxed">{f.t}</p>
                </div>
              ))}
            </div>
            <div className="p-4">
              <div className="text-[10px] font-bold uppercase tracking-wider text-text-muted mb-2">Monitor / Actions</div>
              {detail.actions.map((f, i) => (
                <div key={i} className="flex gap-2 items-start mb-2">
                  <span className="w-1.5 h-1.5 rounded-full mt-1.5 flex-shrink-0" style={{ background: f.c }} />
                  <p className="text-xs leading-relaxed">{f.t}</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      <WellnessSection checkins={checkins} />
    </div>
  )
}

function WellnessSection({ checkins }: { checkins: DailyCheckinRecord[] }) {
  if (checkins.length === 0) {
    return (
      <div>
        <div className="text-[10px] font-bold uppercase tracking-widest text-text-muted mb-3">Wellness since TRT start</div>
        <div className="card text-text-muted text-sm">No daily check-ins yet. Log a check-in in the iOS app to populate.</div>
      </div>
    )
  }
  const data = checkins.map(c => ({
    date: c.checkin_date.slice(5),
    sleep: c.sleep ?? null,
    energy: c.energy ?? null,
    wellbeing: c.wellbeing ?? null,
  }))
  const series = [
    { key: 'sleep',     label: 'Sleep',     color: '#4f8ef7' },
    { key: 'energy',    label: 'Energy',    color: '#f5a623' },
    { key: 'wellbeing', label: 'Wellbeing', color: '#2dd4a0' },
  ] as const
  return (
    <div>
      <div className="text-[10px] font-bold uppercase tracking-widest text-text-muted mb-3">Wellness since TRT start</div>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        {series.map(s => (
          <div key={s.key} className="card">
            <div className="text-[11px] font-semibold mb-2" style={{ color: s.color }}>{s.label} <span className="text-text-muted font-normal">(1–10)</span></div>
            <div style={{ width: '100%', height: 110 }}>
              <ResponsiveContainer>
                <BarChart data={data} margin={{ top: 4, right: 4, bottom: 0, left: -20 }}>
                  <CartesianGrid stroke="rgba(255,255,255,0.05)" vertical={false} />
                  <XAxis dataKey="date" tick={{ fontSize: 9, fill: 'var(--text-muted)' }} interval="preserveStartEnd" />
                  <YAxis domain={[0, 10]} tick={{ fontSize: 9, fill: 'var(--text-muted)' }} />
                  <Tooltip contentStyle={{ background: 'var(--surface-2)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 8, fontSize: 11 }} />
                  <Bar dataKey={s.key} fill={s.color} radius={[3, 3, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

function BloodworkTab({ grouped }: { grouped: Map<string, BloodMarkerRecord[]> }) {
  const presentKeys = MARKER_ORDER.filter(k => (grouped.get(k)?.length ?? 0) > 0)
  return (
    <div className="space-y-4">
      <div className="rounded-xl px-4 py-3 text-xs" style={{ background: 'rgba(245,166,35,.07)', border: '1px solid rgba(245,166,35,.2)', color: 'var(--text-dim)' }}>
        <span className="font-semibold" style={{ color: '#f5a623' }}>Disclaimer:</span> All bloodwork via licensed physician (iMedical Sydney). Not medical advice.
      </div>
      {presentKeys.length === 0 ? (
        <div className="card text-text-muted text-sm">No bloodwork yet. Add a panel in the Add Data tab.</div>
      ) : (
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
          {presentKeys.map(key => {
            const list = grouped.get(key)!
            const latest = list[list.length - 1]
            const prior = list.length > 1 ? list[list.length - 2] : null
            const meta = MARKER_META[key]
            const refHigh = latest.reference_high ?? meta.refHigh
            const refLow = latest.reference_low ?? meta.refLow
            const status = statusFor(latest.value, refHigh)
            const stripColor = status === 'flag' ? '#f06b4b' : status === 'warn' ? '#f5a623' : '#4ade80'
            const textColor = status === 'flag' ? '#f06b4b' : status === 'warn' ? '#f5a623' : '#4ade80'
            const trend = prior ? (latest.value > prior.value ? '↑' : latest.value < prior.value ? '↓' : '→') : ''
            return (
              <div key={key} className="card relative overflow-hidden" style={{ padding: '12px 14px' }}>
                <span className="absolute left-0 top-0 h-full w-[3px]" style={{ background: stripColor }} />
                <div className="text-[11px] text-text-muted">{meta.name}</div>
                <div className="text-base font-bold mt-0.5" style={{ color: textColor }}>
                  {latest.value}
                  <span className="text-[10px] font-normal text-text-muted ml-1">{latest.units ?? meta.unit}</span>
                </div>
                <div className="text-[10px] text-text-muted mt-0.5">
                  Ref {refLow}–{refHigh}{prior ? ` · Prev ${prior.value}` : ''}
                </div>
                <div className="text-[11px] mt-1" style={{ color: textColor }}>
                  {trend && <span className="mr-1">{trend}</span>}{meta.note[status]}
                </div>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}

function HormonesTab({ grouped }: { grouped: Map<string, BloodMarkerRecord[]> }) {
  const [openIds, setOpenIds] = useState<Set<string>>(new Set())
  function toggle(id: string) {
    setOpenIds(prev => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }
  return (
    <div className="space-y-3">
      <div className="text-[10px] font-bold uppercase tracking-widest text-text-muted">What each hormone means</div>
      <div className="grid md:grid-cols-2 gap-3">
        {HORMONES.map(h => {
          const expanded = openIds.has(h.id)
          const list = grouped.get(h.id) ?? []
          const meta = MARKER_META[h.id]
          const refHigh = list[0]?.reference_high ?? meta?.refHigh ?? 100
          const refLow = list[0]?.reference_low ?? meta?.refLow ?? 0
          const scale = refHigh * 1.45
          return (
            <div key={h.id} className="card !p-0 overflow-hidden">
              <button onClick={() => toggle(h.id)} className="w-full text-left px-3.5 py-3 flex items-center gap-3 border-b border-white/5">
                <div className="w-8 h-8 rounded-lg flex items-center justify-center text-base flex-shrink-0" style={{ background: h.bg }}>{h.icon}</div>
                <div className="flex-1 min-w-0">
                  <div className="text-[13px] font-bold" style={{ color: h.color }}>{h.title}</div>
                  <div className="text-[10px] text-text-muted mt-0.5">{h.unit}</div>
                </div>
                <div className="text-base text-text-muted">{expanded ? '˅' : '›'}</div>
              </button>
              {expanded && (
                <div className="px-3.5 py-3 space-y-3">
                  <p className="text-[12px] text-text-muted leading-relaxed">{h.what}</p>
                  <div className="rounded-lg px-3 py-2 text-[12px] leading-relaxed border" style={{ background: 'var(--surface-2)', borderColor: '#2dd4a0' }}>
                    <strong style={{ color: '#2dd4a0' }}>On TRT:</strong> {h.trt}
                  </div>
                  {list.length === 0 ? (
                    <div className="text-[11px] text-text-muted">No readings yet.</div>
                  ) : (
                    <div className="space-y-1.5">
                      <div className="text-[10px] font-semibold uppercase tracking-wider text-text-muted">Your readings</div>
                      {list.map(row => {
                        const pct = Math.min(97, Math.round((row.value / scale) * 100))
                        const st = statusFor(row.value, refHigh)
                        const col = st === 'flag' ? '#f06b4b' : st === 'warn' ? '#f5a623' : h.color
                        const refPct = Math.round((refLow / scale) * 100)
                        const refW  = Math.round(((refHigh - refLow) / scale) * 100)
                        const label = new Date(row.collected_at).toLocaleDateString('en-AU', { day: '2-digit', month: 'short' })
                        return (
                          <div key={row.id} className="flex items-center gap-2">
                            <div className="text-[10px] text-text-muted w-14 text-right flex-shrink-0">{label}</div>
                            <div className="flex-1 h-5 rounded relative overflow-hidden" style={{ background: 'var(--surface-2)' }}>
                              <div className="absolute top-0 h-full" style={{ left: `${refPct}%`, width: `${refW}%`, background: 'rgba(255,255,255,.06)', borderRight: '1px dashed rgba(255,255,255,.15)' }} />
                              <div className="absolute top-0 h-full rounded" style={{ width: `${pct}%`, background: col }} />
                            </div>
                            <div className="text-[11px] font-bold w-12" style={{ color: col }}>{row.value}</div>
                          </div>
                        )
                      })}
                      <div className="text-[10px] text-text-muted mt-1">Shaded = reference range</div>
                    </div>
                  )}
                </div>
              )}
            </div>
          )
        })}
      </div>
    </div>
  )
}

function PhysicalTab({ currentWeek, healthMetrics }: { currentWeek: number; healthMetrics: HealthMetricRecord[] }) {
  const [sub, setSub] = useState<string>(PHYS[0].key)
  const subTabs = [...PHYS.map(p => ({ key: p.key, label: p.label })), { key: 'biometrics', label: '📊 Biometrics' }]
  const active = PHYS.find(p => p.key === sub)
  return (
    <div className="space-y-3">
      <div className="flex gap-1.5 flex-wrap">
        {subTabs.map(p => (
          <button
            key={p.key}
            onClick={() => setSub(p.key)}
            className={`px-3 py-1.5 rounded-full text-[11px] font-semibold border transition-colors ${
              sub === p.key
                ? 'text-white'
                : 'text-text-muted hover:text-white'
            }`}
            style={{
              background: sub === p.key ? 'var(--surface-2)' : 'transparent',
              borderColor: sub === p.key ? 'rgba(255,255,255,.13)' : 'rgba(255,255,255,.07)',
            }}
          >
            {p.label}
          </button>
        ))}
      </div>
      {sub === 'biometrics' ? (
        <BiometricsSubTab healthMetrics={healthMetrics} />
      ) : (
        <div className="space-y-3">
          {(active ?? PHYS[0]).sections.map((s, i) => {
          const here = currentWeek >= s.wkStart && currentWeek <= s.wkEnd
          return (
            <div key={i} className="grid grid-cols-[80px_1fr] gap-3 items-start">
              <div className={`text-[11px] font-bold text-center rounded-lg py-1.5 px-1.5 ${here ? 'ring-1 ring-accent' : ''}`} style={{ color: '#2dd4a0', background: 'rgba(45,212,160,.1)', border: '1px solid rgba(45,212,160,.2)' }}>
                {s.wk}
              </div>
              <div className="flex flex-col gap-1.5">
                {s.items.map((it, j) => (
                  <div key={j} className="card flex items-start gap-2" style={{ padding: '9px 12px' }}>
                    <span className="w-2 h-2 rounded-full mt-1 flex-shrink-0" style={{ background: it.c }} />
                    <div className="text-[12px] leading-relaxed">
                      {it.text}
                      {it.intensity && (
                        <span
                          className="ml-1.5 text-[10px] px-1.5 py-0.5 rounded-full font-semibold"
                          style={{
                            background:
                              it.intensity === 'strong' ? 'rgba(45,212,160,.12)'
                              : it.intensity === 'mod' ? 'rgba(245,166,35,.12)'
                              : 'rgba(79,142,247,.12)',
                            color:
                              it.intensity === 'strong' ? '#2dd4a0'
                              : it.intensity === 'mod' ? '#f5a623'
                              : '#4f8ef7',
                          }}
                        >
                          {it.intensity === 'mod' ? 'moderate' : it.intensity}
                        </span>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )
        })}
        </div>
      )}
    </div>
  )
}

function BiometricsSubTab({ healthMetrics }: { healthMetrics: HealthMetricRecord[] }) {
  if (healthMetrics.length === 0) {
    return (
      <div className="card text-text-muted text-sm text-center py-10">
        <div className="text-3xl mb-2">📱</div>
        Sync from iOS app to populate. Open the OnTrack app to push Apple Health data.
      </div>
    )
  }

  const by = (type: string) =>
    healthMetrics
      .filter(m => m.metric_type === type)
      .map(m => ({
        date: m.recorded_at.slice(5, 10),
        ts: new Date(m.recorded_at).getTime(),
        value: m.value,
      }))
      .sort((a, b) => a.ts - b.ts)

  const rhr   = by('resting_hr')
  const hrv   = by('hrv')
  const steps = by('steps')
  const vo2   = by('vo2_max')
  const deep  = by('sleep_deep_minutes')
  const rem   = by('sleep_rem_minutes')
  const total = by('sleep_total_minutes')

  const sleepByDate = new Map<string, { date: string; deep: number; rem: number; light: number }>()
  for (const row of total) {
    const d = deep.find(x => x.date === row.date)?.value ?? 0
    const r = rem.find(x => x.date === row.date)?.value ?? 0
    const light = Math.max(0, row.value - d - r)
    sleepByDate.set(row.date, { date: row.date, deep: d, rem: r, light })
  }
  const sleep = Array.from(sleepByDate.values())

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
      <BioCard title="Resting HR" unit="bpm" color="#f06b4b" data={rhr}>
        <LineChart data={rhr} margin={{ top: 4, right: 8, bottom: 0, left: -20 }}>
          <CartesianGrid stroke="rgba(255,255,255,0.05)" vertical={false} />
          <XAxis dataKey="date" tick={{ fontSize: 9, fill: 'var(--text-muted)' }} interval="preserveStartEnd" />
          <YAxis tick={{ fontSize: 9, fill: 'var(--text-muted)' }} domain={['dataMin - 4', 'dataMax + 4']} />
          <Tooltip contentStyle={{ background: 'var(--surface-2)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 8, fontSize: 11 }} />
          <Line type="monotone" dataKey="value" stroke="#f06b4b" strokeWidth={2} dot={false} />
        </LineChart>
      </BioCard>

      <BioCard title="HRV (SDNN)" unit="ms" color="#a78bfa" data={hrv}>
        <LineChart data={hrv} margin={{ top: 4, right: 8, bottom: 0, left: -20 }}>
          <CartesianGrid stroke="rgba(255,255,255,0.05)" vertical={false} />
          <XAxis dataKey="date" tick={{ fontSize: 9, fill: 'var(--text-muted)' }} interval="preserveStartEnd" />
          <YAxis tick={{ fontSize: 9, fill: 'var(--text-muted)' }} domain={['dataMin - 5', 'dataMax + 5']} />
          <Tooltip contentStyle={{ background: 'var(--surface-2)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 8, fontSize: 11 }} />
          <Line type="monotone" dataKey="value" stroke="#a78bfa" strokeWidth={2} dot={false} />
        </LineChart>
      </BioCard>

      <BioCard title="Steps" unit="per day" color="#4ade80" data={steps}>
        <BarChart data={steps} margin={{ top: 4, right: 8, bottom: 0, left: -20 }}>
          <CartesianGrid stroke="rgba(255,255,255,0.05)" vertical={false} />
          <XAxis dataKey="date" tick={{ fontSize: 9, fill: 'var(--text-muted)' }} interval="preserveStartEnd" />
          <YAxis tick={{ fontSize: 9, fill: 'var(--text-muted)' }} />
          <Tooltip contentStyle={{ background: 'var(--surface-2)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 8, fontSize: 11 }} />
          <Bar dataKey="value" fill="#4ade80" radius={[3, 3, 0, 0]} />
        </BarChart>
      </BioCard>

      <BioCard title="VO₂ Max" unit="mL/kg/min" color="#2dd4a0" data={vo2}>
        <LineChart data={vo2} margin={{ top: 4, right: 8, bottom: 0, left: -20 }}>
          <CartesianGrid stroke="rgba(255,255,255,0.05)" vertical={false} />
          <XAxis dataKey="date" tick={{ fontSize: 9, fill: 'var(--text-muted)' }} interval="preserveStartEnd" />
          <YAxis tick={{ fontSize: 9, fill: 'var(--text-muted)' }} domain={['dataMin - 1', 'dataMax + 1']} />
          <Tooltip contentStyle={{ background: 'var(--surface-2)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 8, fontSize: 11 }} />
          <Line type="monotone" dataKey="value" stroke="#2dd4a0" strokeWidth={2} dot={{ r: 3, fill: '#2dd4a0' }} />
        </LineChart>
      </BioCard>

      <div className="card md:col-span-2">
        <div className="flex items-center justify-between mb-2">
          <div className="text-[11px] font-semibold" style={{ color: '#4f8ef7' }}>Sleep stages <span className="text-text-muted font-normal">(minutes per night)</span></div>
          <div className="flex gap-3 text-[10px]">
            <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-sm" style={{ background: '#1e3a8a' }} />Deep</span>
            <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-sm" style={{ background: '#a78bfa' }} />REM</span>
            <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-sm" style={{ background: '#4f8ef7' }} />Light</span>
          </div>
        </div>
        {sleep.length === 0 ? (
          <div className="text-text-muted text-sm py-6 text-center">No sleep data synced yet.</div>
        ) : (
          <div style={{ width: '100%', height: 200 }}>
            <ResponsiveContainer>
              <BarChart data={sleep} margin={{ top: 4, right: 8, bottom: 0, left: -10 }}>
                <CartesianGrid stroke="rgba(255,255,255,0.05)" vertical={false} />
                <XAxis dataKey="date" tick={{ fontSize: 9, fill: 'var(--text-muted)' }} interval="preserveStartEnd" />
                <YAxis tick={{ fontSize: 9, fill: 'var(--text-muted)' }} />
                <Tooltip contentStyle={{ background: 'var(--surface-2)', border: '1px solid rgba(255,255,255,0.1)', borderRadius: 8, fontSize: 11 }} />
                <Bar dataKey="deep"  stackId="s" fill="#1e3a8a" />
                <Bar dataKey="rem"   stackId="s" fill="#a78bfa" />
                <Bar dataKey="light" stackId="s" fill="#4f8ef7" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}
      </div>
    </div>
  )
}

function BioCard({
  title, unit, color, data, children,
}: {
  title: string
  unit: string
  color: string
  data: { date: string; value: number }[]
  children: React.ReactElement
}) {
  const latest = data.length > 0 ? data[data.length - 1].value : null
  return (
    <div className="card">
      <div className="flex items-center justify-between mb-2">
        <div className="text-[11px] font-semibold" style={{ color }}>{title} <span className="text-text-muted font-normal">{unit}</span></div>
        {latest != null && <div className="text-[13px] font-bold" style={{ color }}>{Math.round(latest * 10) / 10}</div>}
      </div>
      {data.length === 0 ? (
        <div className="text-text-muted text-sm py-6 text-center">No readings yet.</div>
      ) : (
        <div style={{ width: '100%', height: 130 }}>
          <ResponsiveContainer>{children}</ResponsiveContainer>
        </div>
      )}
    </div>
  )
}

function JournalTab({
  userId, journal, protocolId, protocolStartDate, onSaved,
}: {
  userId: string
  journal: JournalRecord[]
  protocolId: string | null
  protocolStartDate: string | null
  onSaved: () => void
}) {
  const [open, setOpen] = useState(false)
  const dialogRef = useModalA11y<HTMLDivElement>(open, () => setOpen(false))
  const [date, setDate] = useState(() => new Date().toISOString().slice(0, 10))
  const [body, setBody] = useState('')
  const [tag, setTag] = useState('general')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  function wkFor(d: string): number {
    if (!protocolStartDate) return 1
    const start = new Date(protocolStartDate + 'T00:00:00Z').getTime()
    const end = new Date(d + 'T00:00:00Z').getTime()
    if (isNaN(start) || isNaN(end)) return 1
    return Math.max(1, Math.floor((end - start) / 86400000 / 7) + 1)
  }

  async function save() {
    if (!body.trim()) { setError('Write something first.'); return }
    setSaving(true); setError(null)
    const supabase = createClient()
    const { error: e } = await supabase.from('health_journal').insert({
      user_id: userId,
      protocol_id: protocolId,
      entry_date: date,
      week_number: wkFor(date),
      body: body.trim(),
      tag,
    })
    setSaving(false)
    if (e) { setError(e.message); return }
    setBody(''); setOpen(false); onSaved()
  }

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <div className="text-[10px] font-bold uppercase tracking-widest text-text-muted">Journal</div>
        <button onClick={() => setOpen(true)} className="btn-primary text-xs">+ Add entry</button>
      </div>
      {journal.length === 0 ? (
        <div className="card text-text-muted text-sm text-center py-10">
          <div className="text-3xl mb-2">📔</div>
          No entries yet. Tap + Add entry to start logging.
        </div>
      ) : (
        <div className="space-y-2">
          {journal.map(e => {
            const col = TAG_COLORS[e.tag ?? 'general'] ?? TAG_COLORS.general
            return (
              <div key={e.id} className="card" style={{ padding: '12px 15px' }}>
                <div className="text-[11px] text-text-muted mb-1 flex items-center gap-2">
                  {e.week_number != null && (
                    <span className="text-[10px] font-bold px-2 py-0.5 rounded-full" style={{ background: 'rgba(45,212,160,.1)', color: '#2dd4a0' }}>
                      Week {e.week_number}
                    </span>
                  )}
                  {new Date(e.entry_date).toLocaleDateString('en-AU', { day: 'numeric', month: 'short', year: 'numeric' })}
                </div>
                <div className="text-[13px] leading-relaxed whitespace-pre-wrap">{e.body}</div>
                {e.tag && (
                  <span className="inline-block text-[10px] px-2 py-0.5 rounded-full mt-2 font-semibold" style={{ background: `${col}1f`, color: col, border: `1px solid ${col}33` }}>
                    {e.tag}
                  </span>
                )}
              </div>
            )
          })}
        </div>
      )}
      {open && (
        <div
          onClick={() => setOpen(false)}
          className="fixed inset-0 z-30 flex items-end md:items-center justify-center bg-black/60 p-4"
        >
          <div
            ref={dialogRef}
            role="dialog"
            aria-modal="true"
            aria-labelledby="pc-journal-title"
            onClick={e => e.stopPropagation()}
            className="card w-full max-w-md max-h-[90vh] overflow-y-auto"
          >
            <div className="flex items-center justify-between mb-3">
              <h3 id="pc-journal-title" className="font-semibold">New journal entry</h3>
              <button onClick={() => setOpen(false)} aria-label="Close" className="text-text-muted hover:text-white text-sm">Close</button>
            </div>
            <div className="space-y-3">
              <div className="grid grid-cols-2 gap-2">
                <label className="block">
                  <span className="text-xs text-text-dim">Date</span>
                  <input type="date" className="input mt-1" value={date} onChange={e => setDate(e.target.value)} />
                </label>
                <label className="block">
                  <span className="text-xs text-text-dim">Week</span>
                  <input className="input mt-1" value={wkFor(date)} disabled />
                </label>
              </div>
              <label className="block">
                <span className="text-xs text-text-dim">Tag</span>
                <select className="input mt-1" value={tag} onChange={e => setTag(e.target.value)}>
                  {TAG_OPTIONS.map(t => <option key={t} value={t}>{t}</option>)}
                </select>
              </label>
              <label className="block">
                <span className="text-xs text-text-dim">Entry</span>
                <textarea className="input mt-1" rows={6} value={body} onChange={e => setBody(e.target.value)} placeholder="Energy, mood, sleep, injection notes, gym performance…" />
              </label>
              {error && <p className="text-xs text-red-400">{error}</p>}
              <button onClick={save} disabled={saving} className="btn-primary w-full">{saving ? 'Saving…' : 'Save'}</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

function AddDataTab({
  userId, recentMetrics, onSaved,
}: {
  userId: string
  recentMetrics: BodyMetricRecord[]
  onSaved: () => void
}) {
  const [date, setDate] = useState(() => new Date().toISOString().slice(0, 10))
  const [label, setLabel] = useState('')
  const [values, setValues] = useState<Record<string, string>>({})
  const [saving, setSaving] = useState(false)
  const [bloodError, setBloodError] = useState<string | null>(null)
  const [bloodToast, setBloodToast] = useState<string | null>(null)

  const [bDate, setBDate] = useState(() => new Date().toISOString().slice(0, 10))
  const [bWeight, setBWeight] = useState('')
  const [bFat, setBFat] = useState('')
  const [bWaist, setBWaist] = useState('')
  const [bSaving, setBSaving] = useState(false)
  const [bError, setBError] = useState<string | null>(null)
  const [bToast, setBToast] = useState<string | null>(null)

  async function savePanel() {
    setBloodError(null); setBloodToast(null)
    const rows = MARKER_ORDER
      .map(key => {
        const v = values[key]
        if (v === undefined || v === '') return null
        const num = parseFloat(v)
        if (!Number.isFinite(num)) return null
        const meta = MARKER_META[key]
        return {
          user_id: userId,
          marker: key,
          value: num,
          units: meta.unit,
          reference_low: meta.refLow,
          reference_high: meta.refHigh,
          collected_at: `${date}T00:00:00Z`,
          notes: label || null,
        }
      })
      .filter(Boolean) as Record<string, unknown>[]
    if (rows.length === 0) { setBloodError('Enter at least one marker value.'); return }
    setSaving(true)
    const supabase = createClient()
    const { error } = await supabase.from('blood_markers').insert(rows)
    setSaving(false)
    if (error) { setBloodError(error.message); return }
    setBloodToast(`Saved ${rows.length} markers ✓`)
    setValues({}); setLabel('')
    onSaved()
  }

  async function saveMetric() {
    setBError(null); setBToast(null)
    const payload: Record<string, unknown> = {
      user_id: userId,
      metric_date: bDate,
      source: 'manual',
    }
    if (bWeight !== '') payload.weight_kg = parseFloat(bWeight)
    if (bFat    !== '') payload.body_fat_pct = parseFloat(bFat)
    if (bWaist  !== '') payload.waist_cm = parseFloat(bWaist)
    if (!('weight_kg' in payload) && !('body_fat_pct' in payload) && !('waist_cm' in payload)) {
      setBError('Enter at least one value.'); return
    }
    setBSaving(true)
    const supabase = createClient()
    const { error } = await supabase.from('body_metrics').insert(payload)
    setBSaving(false)
    if (error) { setBError(error.message); return }
    setBToast('Saved ✓')
    setBWeight(''); setBFat(''); setBWaist('')
    onSaved()
  }

  return (
    <div className="space-y-5">
      <div>
        <div className="text-[10px] font-bold uppercase tracking-widest text-text-muted mb-3">Add new blood panel</div>
        <div className="card space-y-3">
          <div className="grid grid-cols-2 gap-3">
            <label className="block">
              <span className="text-xs text-text-dim">Draw date</span>
              <input type="date" className="input mt-1" value={date} onChange={e => setDate(e.target.value)} />
            </label>
            <label className="block">
              <span className="text-xs text-text-dim">Label (e.g. &quot;Wk 8&quot;)</span>
              <input className="input mt-1" value={label} onChange={e => setLabel(e.target.value)} placeholder="Wk 8" />
            </label>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-3 gap-2">
            {MARKER_ORDER.map(key => {
              const meta = MARKER_META[key]
              return (
                <label key={key} className="block">
                  <span className="text-[10px] text-text-muted">{meta.name} ({meta.unit})</span>
                  <input
                    type="number"
                    step="any"
                    className="input mt-0.5 text-sm"
                    placeholder="—"
                    value={values[key] ?? ''}
                    onChange={e => setValues(v => ({ ...v, [key]: e.target.value }))}
                  />
                </label>
              )
            })}
          </div>
          {bloodError && <p className="text-xs text-red-400">{bloodError}</p>}
          {bloodToast && <p className="text-xs" style={{ color: '#2dd4a0' }}>{bloodToast}</p>}
          <div className="flex justify-end gap-2">
            <button onClick={() => setValues({})} className="text-xs px-4 py-2 rounded-lg" style={{ background: 'var(--surface-2)', border: '1px solid rgba(255,255,255,.13)', color: 'var(--text-dim)' }}>Clear</button>
            <button onClick={savePanel} disabled={saving} className="btn-primary text-xs">{saving ? 'Saving…' : 'Save panel'}</button>
          </div>
        </div>
      </div>

      <div>
        <div className="text-[10px] font-bold uppercase tracking-widest text-text-muted mb-3">Body metrics — quick add</div>
        <div className="card space-y-3">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            <label className="block">
              <span className="text-xs text-text-dim">Date</span>
              <input type="date" className="input mt-1" value={bDate} onChange={e => setBDate(e.target.value)} />
            </label>
            <label className="block">
              <span className="text-xs text-text-dim">Weight (kg)</span>
              <input type="number" step="any" className="input mt-1" value={bWeight} onChange={e => setBWeight(e.target.value)} placeholder="—" />
            </label>
            <label className="block">
              <span className="text-xs text-text-dim">Body fat (%)</span>
              <input type="number" step="any" className="input mt-1" value={bFat} onChange={e => setBFat(e.target.value)} placeholder="—" />
            </label>
            <label className="block">
              <span className="text-xs text-text-dim">Waist (cm)</span>
              <input type="number" step="any" className="input mt-1" value={bWaist} onChange={e => setBWaist(e.target.value)} placeholder="—" />
            </label>
          </div>
          {bError && <p className="text-xs text-red-400">{bError}</p>}
          {bToast && <p className="text-xs" style={{ color: '#2dd4a0' }}>{bToast}</p>}
          <div className="flex justify-end">
            <button onClick={saveMetric} disabled={bSaving} className="btn-primary text-xs">{bSaving ? 'Saving…' : 'Save metric'}</button>
          </div>
          {recentMetrics.length > 0 && (
            <div className="border-t border-white/5 pt-3">
              <div className="text-[10px] font-bold uppercase tracking-wider text-text-muted mb-2">Recent</div>
              <div className="space-y-1">
                {recentMetrics.map(m => (
                  <div key={m.id} className="text-[12px] text-text-dim flex justify-between">
                    <span>{new Date(m.metric_date).toLocaleDateString('en-AU', { day: 'numeric', month: 'short', year: 'numeric' })}</span>
                    <span className="text-text-muted">
                      {m.weight_kg != null ? `${m.weight_kg}kg` : '—'} · {m.body_fat_pct != null ? `${m.body_fat_pct}%` : '—'} · {m.waist_cm != null ? `${m.waist_cm}cm` : '—'}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
