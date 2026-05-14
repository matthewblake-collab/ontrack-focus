export type BodyMetricsRow = {
  id?: string
  metric_date: string  // yyyy-MM-dd
  weight_kg: number | null
  body_fat_pct: number | null
  muscle_mass_kg: number | null
  waist_cm: number | null
  chest_cm: number | null
  arm_cm: number | null
  neck_cm: number | null
  notes: string | null
  source: string | null
}

export const BODY_METRIC_FIELDS: { key: keyof BodyMetricsRow; label: string; unit: string }[] = [
  { key: 'weight_kg',      label: 'Weight',       unit: 'kg' },
  { key: 'body_fat_pct',   label: 'Body Fat',     unit: '%'  },
  { key: 'muscle_mass_kg', label: 'Muscle Mass',  unit: 'kg' },
  { key: 'waist_cm',       label: 'Waist',        unit: 'cm' },
  { key: 'chest_cm',       label: 'Chest',        unit: 'cm' },
  { key: 'arm_cm',         label: 'Arm',          unit: 'cm' },
  { key: 'neck_cm',        label: 'Neck',         unit: 'cm' },
]
