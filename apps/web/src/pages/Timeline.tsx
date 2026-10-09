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

// Palet kapsul hari ala template referensi (merah, nila, kuning, biru,
// oranye, ungu, hijau) — dipakai berulang untuk rentang > 7 hari.
const DAY_COLORS = ['#f0506e', '#5b5bd6', '#ffc531', '#1e88e5', '#ff8a3d', '#6a3fa0', '#8bc34a']

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
const dayName = (iso: string) => DAYS[parseLocal(iso).getDay()]
const dayNum = (iso: string) => {
  const d = parseLocal(iso)
  return `${d.getDate()}/${d.getMonth() + 1}`
}

type DayGroup = { date: string; items: Activity[] }

// Konektor lengkung S dari kapsul ke kartu (warna ikut kapsul).
function Curve({ color, flip }: { color: string; flip?: boolean }) {
  return (
    <svg viewBox="0 0 100 56" preserveAspectRatio="none" className="h-14 w-16"
      style={flip ? { transform: 'scaleY(-1)' } : undefined}>
      <path d="M50,56 C50,42 28,40 28,26 C28,12 50,12 50,0"
        fill="none" stroke={color} strokeWidth={4} strokeLinecap="round" />
    </svg>
  )
}

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

  const togglePhotos = async (a: Activity) => {
    if (openId === a.id) { setOpenId(null); return }
    setOpenId(a.id); setPhotos([])
    try {
      const det = await fetchActivity(a.id)
      setPhotos(det.photos ?? [])
    } catch (e) { setMsg(`gagal muat foto: ${String(e)}`) }
  }

  const scrollToDay = (iso: string) => {
    document.getElementById(`tl-day-${iso}`)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }

  const finp = 'rounded-lg border px-3 py-2'
  return (
    <div className="flex flex-col gap-4">
      <div className="print:hidden">
        <h2 className="text-theme-xl font-semibold">Timeline Mingguan</h2>
        <p className="text-theme-sm text-gray-500">Laporan presentasi management: kegiatan per tanggal + foto</p>
      </div>
      {/* Toolbar 1 baris: filter + ringkasan kompak */}
      <div className="flex flex-wrap items-center gap-x-3 gap-y-2 rounded-2xl border bg-white px-4 py-3 print:hidden">
        <input type="date" className={finp} value={df} max={dt} onChange={(e) => setDf(e.target.value)} />
        <span>–</span>
        <input type="date" className={finp} value={dt} min={df} onChange={(e) => setDt(e.target.value)} />
        <input className={`${finp} w-32`} list="tl-crew" value={crew} onChange={(e) => setCrew(e.target.value)} placeholder="Crew: semua" />
        <input className={`${finp} w-32`} list="tl-cat" value={cat} onChange={(e) => setCat(e.target.value)} placeholder="Kategori" />
        <datalist id="tl-crew">{CREWS.map((c) => (<option key={c} value={c} />))}</datalist>
        <datalist id="tl-cat">{CATS.map((c) => (<option key={c} value={c} />))}</datalist>
        <button className="rounded-lg bg-brand-500 px-4 py-2 text-white" onClick={apply}>Tampilkan</button>
        <button className="rounded-lg border px-4 py-2" onClick={() => window.print()}>Cetak / PDF</button>
        <span className="hidden h-8 w-px bg-gray-200 xl:block" />
        <div className="flex flex-wrap items-center gap-x-4 gap-y-1">
          {[
            { value: all.length, label: 'kegiatan' },
            { value: `${activeDays}/${days.length}`, label: 'hari aktif' },
            { value: photoTotal, label: 'foto' },
            { value: applied.crew || 'Semua', label: 'crew' },
          ].map((s) => (
            <span key={s.label} className="whitespace-nowrap">
              <span className="text-title-sm font-bold">{s.value}</span>
              <span className="ml-1 text-theme-xs text-gray-500">{s.label}</span>
            </span>
          ))}
        </div>
      </div>
      {msg && <p className="text-theme-sm text-red-600 print:hidden">{msg}</p>}
      {loading && <p className="text-theme-sm text-gray-500">Memuat timeline...</p>}

      {/* Infografis Weekly Timeline ala template */}
      {days.length > 0 && (
        <div className="overflow-x-auto rounded-2xl border bg-white p-6">
          <h2 className="text-center text-2xl font-bold">
            Weekly Timeline <span className="font-normal text-gray-500">— {applied.crew || 'Semua Crew'}</span>
          </h2>
          <p className="mt-1 text-center text-theme-sm text-gray-500">
            {fmtDay(applied.df)} – {fmtDay(applied.dt)}
          </p>
          <div className="relative mt-8 min-w-[900px]">
            {/* Rel abu-abu + panah kiri kanan, sejajar tengah kapsul */}
            <div className="absolute right-0 left-0 z-0 flex items-center" style={{ top: 228 }}>
              <span className="h-0 w-0 shrink-0 border-y-8 border-r-[14px] border-y-transparent border-r-gray-300" />
              <div className="h-3 flex-1 bg-gray-300" />
              <span className="h-0 w-0 shrink-0 border-y-8 border-l-[14px] border-y-transparent border-l-gray-300" />
            </div>
            <div className="relative z-10 flex">
              {days.map((d, i) => {
                const color = DAY_COLORS[i % DAY_COLORS.length]
                const above = i % 2 === 0
                const card = (
                  <div className="flex h-40 flex-col items-center justify-end overflow-hidden px-2 text-center">
                    {d.items.length === 0 ? (
                      <p className="text-theme-sm text-gray-400">Tidak ada kegiatan</p>
                    ) : (
                      <button className="w-full" onClick={() => scrollToDay(d.date)} title="Lihat detail">
                        <p className="text-theme-sm font-bold">{d.items.length} kegiatan</p>
                        {d.items.slice(0, 2).map((a) => (
                          <p key={a.id} className="mt-1 line-clamp-2 text-theme-xs text-gray-600">{a.title}</p>
                        ))}
                        {d.items.length > 2 && (
                          <p className="text-theme-xs text-gray-400">+{d.items.length - 2} lainnya</p>
                        )}
                      </button>
                    )}
                  </div>
                )
                const capsule = (
                  <div className="flex justify-center">
                    <span
                      className="rounded-full px-6 py-2 font-bold whitespace-nowrap text-white"
                      style={{ backgroundColor: color, printColorAdjust: 'exact' }}>
                      {dayName(d.date)}
                      <span className="ml-2 text-theme-xs font-normal opacity-90">{dayNum(d.date)}</span>
                    </span>
                  </div>
                )
                return (
                  <div key={d.date} className="flex min-w-0 flex-1 flex-col items-center">
                    {above ? card : <div className="h-40" />}
                    {above
                      ? <Curve color={color} />
                      : <div className="flex h-14 items-center"><span className="size-2 rounded-full" style={{ backgroundColor: color }} /></div>}
                    {capsule}
                    {above
                      ? <div className="flex h-14 items-center"><span className="size-2 rounded-full" style={{ backgroundColor: color }} /></div>
                      : <Curve color={color} flip />}
                    {above ? <div className="h-40" /> : card}
                  </div>
                )
              })}
            </div>
          </div>
        </div>
      )}

      {/* Detail per tanggal */}
      <div className="flex flex-col gap-6">
        {days.map((d) => (
          <div key={d.date} id={`tl-day-${d.date}`} className="scroll-mt-4">
            <div className="flex items-center gap-2">
              <h3 className="font-semibold">{fmtDay(d.date)}</h3>
              <span className="rounded-full bg-gray-100 px-2 py-0.5 text-theme-xs text-gray-600">
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
