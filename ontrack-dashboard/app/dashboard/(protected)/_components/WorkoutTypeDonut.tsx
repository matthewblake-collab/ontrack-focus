'use client'

import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from 'recharts'
import { workoutTypeBreakdown, type WorkoutImportRow } from '../_lib/workouts'

const COLOURS = ['#2dd4a0', '#facc15', '#60a5fa', '#c084fc', '#fb7185', '#34d399', '#fbbf24']

export function WorkoutTypeDonut({ rows }: { rows: WorkoutImportRow[] }) {
  const data = workoutTypeBreakdown(rows)
  if (data.length === 0) return null

  return (
    <div className="card">
      <h3 className="text-sm font-medium mb-3">Workout types</h3>
      <div className="h-48">
        <ResponsiveContainer>
          <PieChart>
            <Pie
              data={data}
              dataKey="count"
              nameKey="name"
              innerRadius={40}
              outerRadius={70}
              paddingAngle={2}
              label={({ name }) => name}
              labelLine={false}
              style={{ fontSize: 11, fill: 'var(--text-dim)' }}
            >
              {data.map((_, i) => (
                <Cell key={i} fill={COLOURS[i % COLOURS.length]} />
              ))}
            </Pie>
            <Tooltip
              contentStyle={{
                background: 'var(--surface)',
                border: '1px solid rgba(255,255,255,0.1)',
                borderRadius: 8,
                fontSize: 12,
              }}
            />
          </PieChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}
