import { useEffect, useState } from 'react'
import {
  fetchActivitiesByDate, fetchActivity, activityPhotoUrl, todayLocal,
  type Activity,
} from '../api/client'

const CREWS = ['Pumping', 'Lighting', 'Mobile', 'Grader', 'PCH']
const CATS = ['Proker', 'FUI', 'USM', 'SCM']
const MONTHS = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember']
const DAYS = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu']
const MAX_DAYS = 31

const parseLocal = (iso: string) => {
  const [y, m, d] = iso.split('-').map(Number)
  return new Date(y, (m || 1) - 1, d || 1)
}
const toISO = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
const rangeDates = (from: string, to: string): string[] => {
  const out: string[] = []
  const cur = parseLocal(from)
  const end = parseLocal(to)
  while (cur <= end && out.length < MAX_DAYS) {
    out.push(toISO(cur))
    cur.setDate(cur.getDate() + 1)
  }
  return out
}
const fmtDay = (iso: string) => {
  const d = parseLocal(iso)
  return `${DAYS[d.getDay()]}, ${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`
}
const fmtShort = (iso: string) => {
  const d = parseLocal(iso)
  return `${d.getDate()}/${d.getMonth() + 1}`
}

type DayGroup = { date: string; items: Activity[] }

export default function TimelinePage() {
  const [df, setDf] = useState(todayLocal(6))
  const [dt, setDt] = useState(todayLocal())
  const [crew, setCrew] = useState('')
  const [cat, setCat] = useState('')
  const [applied, setApplied] = useState({ df: todayLocal(6), dt: todayLocal(), crew: '', cat: '' })
  const [days, setDays] = useState<DayGroup[]>([])
  const [loading, setLoading] = useState(false)
  const [msg, setMsg] = useState('')
  const [openId, setOpenId] = useState<string | null>(null)
  const [photos, setPhotos] = useState<{ id: string; orig_name?: string | null }[]>([])

  const load = async (f = applied) => {
    const dates = rangeDates(f.df, f.dt)
    if (parseLocal(f.dt) < parseLocal(f.df)) { setMsg('Tanggal akhir sebelum tanggal awal.'); return }
    try {
      setMsg(''); setLoading(true); setOpenId(null)
      const perDay = await Promise.all(dates.map(async (d) => {
        try { return await fetchActivitiesByDate(d) } catch { return [] as Activity[] }
      }))
      const cw = f.crew.trim().toLowerCase()
      const ct = f.cat.trim().toLowerCase()
      setDays(dates.map((d, i) => ({
        date: d,
        items: perDay[i].filter((a) =>
          (!cw || (a.crew ?? '').toLowerCase().includes(cw)) &&
          (!ct || (a.category ?? '').toLowerCase().includes(ct))),
      })))
    } catch (e) { setMsg(`gagal: ${String(e)}`) }
    finally { setLoading(false) }
  }
  useEffect(() => { load() }, [])
  const apply = () => {
    const f = { df, dt, crew: crew.trim(), cat: cat.trim() }
    setApplied(f)
    load(f)
  }

  const all = days.flatMap((d) => d.items)
  const activeDays = days.filter((d) => d.items.length > 0).length
  const photoTotal = all.reduce((n, a) => n + (typeof a.photos === 'number' ? a.photos : 0), 0)
  const maxN = Math.max(1, ...days.map((d) => d.items.length))
  const busiest = days.reduce<DayGroup | null>(
    (b, d) => (!b || d.items.length > b.items.length ? d : b), null)

  const togglePhotos = async (a: Activity) => {
    if (openId === a.id) { setOpenId(null); return }
    setOpenId(a.id); setPhotos([])
    try {
      const det = await fetchActivity(a.id)
      setPhotos(det.photos ?? [])
    } catch (e) { setMsg(`gagal muat foto: ${String(e)}`) }
  }

  const finp = 'rounded-lg border px-3 py-2'
  return (
    <div className="flex flex-col gap-4">
      <div className="print:hidden">
        <h2 className="text-theme-xl font-semibold">Timeline Mingguan</h2>
        <p className="text-theme-sm text-gray-500">Laporan presentasi management: kegiatan per tanggal + foto</p>
      </div>
      {/* Baris judul khusus cetak */}
      <div className="hidden print:block">
        <h2 className="text-xl font-bold">Laporan Mingguan Activity — {applied.crew || 'Semua Crew'}</h2>
        <p className="text-sm text-gray-600">{fmtDay(applied.df)} – {fmtDay(applied.dt)}</p>
      </div>
      <div className="flex flex-wrap items-center gap-2 print:hidden">
        <input type="date" className={finp} value={df} max={dt} onChange={(e) => setDf(e.target.value)} />
        <span>–</span>
        <input type="date" className={finp} value={dt} min={df} onChange={(e) => setDt(e.target.value)} />
        <input className={`${finp} w-32`} list="tl-crew" value={crew} onChange={(e) => setCrew(e.target.value)} placeholder="Crew: semua" />
        <input className={`${finp} w-32`} list="tl-cat" value={cat} onChange={(e) => setCat(e.target.value)} placeholder="Kategori" />
        <datalist id="tl-crew">{CREWS.map((c) => (<option key={c} value={c} />))}</datalist>
        <datalist id="tl-cat">{CATS.map((c) => (<option key={c} value={c} />))}</datalist>
        <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={apply}>Tampilkan</button>
        <button className="rounded-lg border px-4 py-2" onClick={() => window.print()}>Cetak / PDF</button>
      </div>
      {msg && <p className="text-theme-sm text-red-600 print:hidden">{msg}</p>}
      {loading && <p className="text-theme-sm text-gray-500">Memuat timeline...</p>}

      {/* Ringkasan */}
      <div className="grid grid-cols-2 gap-4 xl:grid-cols-4">
        {[
          { label: 'Total kegiatan', value: all.length },
          { label: 'Hari aktif', value: `${activeDays} / ${days.length}` },
          { label: 'Total foto', value: photoTotal },
          { label: 'Hari tersibuk', value: busiest && busiest.items.length > 0 ? `${fmtShort(busiest.date)} (${busiest.items.length})` : '-' },
        ].map((c) => (
          <div key={c.label} className="rounded-2xl border bg-white p-5">
            <p className="text-theme-sm text-gray-500">{c.label}</p>
            <p className="mt-1 text-title-sm font-bold">{c.value}</p>
          </div>
        ))}
      </div>

      {/* Mini grafik per hari */}
      {days.length > 0 && (
        <div className="rounded-2xl border bg-white p-5">
          <h3 className="font-semibold">Kegiatan per hari</h3>
          <div className="mt-3 flex h-32 items-end gap-1">
            {days.map((d) => (
              <div key={d.date} className="flex min-w-0 flex-1 flex-col items-center gap-1" title={`${fmtDay(d.date)}: ${d.items.length}`}>
                <span className="text-theme-xs font-semibold">{d.items.length > 0 ? d.items.length : ''}</span>
                <div
                  className="w-full max-w-8 rounded-t bg-brand-500"
                  style={{ height: `${Math.max(d.items.length > 0 ? 8 : 2, (d.items.length / maxN) * 100)}%` }}
                />
                <span className="text-theme-xs text-gray-500">{fmtShort(d.date)}</span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Timeline */}
      <div className="relative ml-2 flex flex-col gap-6 border-l-2 border-brand-200 pl-6">
        {days.map((d) => (
          <div key={d.date} className="relative">
            <span className={`absolute -left-[34px] top-1 flex size-4 items-center justify-center rounded-full ${d.items.length > 0 ? 'bg-brand-500' : 'border-2 border-gray-300 bg-white'}`}>
              {d.items.length > 0 && <span className="size-1.5 rounded-full bg-white" />}
            </span>
            <div className="flex items-center gap-2">
              <h3 className="font-semibold">{fmtDay(d.date)}</h3>
              <span className={`rounded-full px-2 py-0.5 text-theme-xs ${d.items.length > 0 ? 'bg-brand-50 text-brand-600' : 'bg-gray-100 text-gray-400'}`}>
                {d.items.length} kegiatan
              </span>
            </div>
            {d.items.length === 0 && (
              <p className="mt-1 text-theme-sm text-gray-400">Tidak ada kegiatan.</p>
            )}
            <div className="mt-2 grid grid-cols-1 gap-3 xl:grid-cols-2">
              {d.items.map((a) => (
                <div key={a.id} className="flex gap-3 rounded-2xl border bg-white p-3 break-inside-avoid">
                  {a.cover_id
                    ? <img src={activityPhotoUrl(a.id, a.cover_id)} alt="" loading="lazy"
                        className="h-20 w-20 shrink-0 rounded-xl object-cover" />
                    : <span className="flex h-20 w-20 shrink-0 items-center justify-center rounded-xl bg-gray-100 text-gray-400">—</span>}
                  <div className="min-w-0 flex-1">
                    <p className="font-medium">{a.title}</p>
                    <p className="mt-0.5 truncate text-theme-sm text-gray-500">
                      {[a.crew, a.category, a.cn].filter(Boolean).join(' • ')}
                      {typeof a.photos === 'number' && a.photos > 0 ? ` • ${a.photos} foto` : ''}
                    </p>
                    {a.description && (
                      <p className="mt-1 line-clamp-2 text-theme-sm text-gray-600">{a.description}</p>
                    )}
                    {typeof a.photos === 'number' && a.photos > 0 && (
                      <button className="mt-1 text-theme-sm text-brand-600 underline print:hidden"
                        onClick={() => togglePhotos(a)}>
                        {openId === a.id ? 'Sembunyikan foto' : `Lihat ${a.photos} foto`}
                      </button>
                    )}
                    {openId === a.id && (
                      <div className="mt-2 grid grid-cols-3 gap-1">
                        {photos.map((p) => (
                          <a key={p.id} href={activityPhotoUrl(a.id, p.id)} target="_blank" rel="noreferrer">
                            <img src={activityPhotoUrl(a.id, p.id)} alt={p.orig_name ?? ''}
                              loading="lazy" className="h-16 w-full rounded-lg object-cover" />
                          </a>
                        ))}
                        {photos.length === 0 && (
                          <p className="text-theme-sm text-gray-400">Memuat foto...</p>
                        )}
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
