import { useEffect, useRef } from 'react'
import flatpickr from 'flatpickr'

type Props = {
  /** Tanggal dalam format API `YYYY-MM-DD` */
  value: string
  min?: string
  max?: string
  placeholder?: string
  onChange: (v: string) => void
}

const toApiDate = (d: Date) => {
  const p = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`
}

const PREV_ARROW =
  '<svg class="stroke-current" width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M15.25 6L9 12.25L15.25 18.5" stroke="" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>'
const NEXT_ARROW =
  '<svg class="stroke-current" width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M8.75 19L15 12.75L8.75 6.5" stroke="" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/></svg>'

/**
 * Input pemilih tanggal model "Date Picker Input" TailAdmin (flatpickr).
 * Nilai tetap `YYYY-MM-DD` untuk API; tampilan `MM/DD/YYYY`;
 * ketikan manual diblokir (`allowInput: false`) — hanya lewat kalender.
 */
export function DatePicker({ value, min, max, placeholder, onChange }: Props) {
  const inputRef = useRef<HTMLInputElement>(null)
  const cbRef = useRef(onChange)
  cbRef.current = onChange

  useEffect(() => {
    const el = inputRef.current
    if (!el) return
    const fp = flatpickr(el, {
      dateFormat: 'Y-m-d',
      altInput: true,
      altFormat: 'm/d/Y',
      defaultDate: value || undefined,
      minDate: min || undefined,
      maxDate: max || undefined,
      allowInput: false,
      clickOpens: true,
      monthSelectorType: 'static',
      prevArrow: PREV_ARROW,
      nextArrow: NEXT_ARROW,
      onChange: (dates) => {
        if (dates[0]) cbRef.current(toApiDate(dates[0]))
      },
    })
    return () => {
      fp.destroy()
    }
    // init sekali; sinkronisasi props lewat efek di bawah
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    const fp = (inputRef.current as unknown as { _flatpickr?: {
      input: HTMLInputElement
      setDate: (d: string, trigger: boolean) => void
      set: (k: string, v: string | undefined) => void
    } } | null)?._flatpickr
    if (!fp) return
    if (value && fp.input.value !== value) fp.setDate(value, false)
    fp.set('minDate', min || undefined)
    fp.set('maxDate', max || undefined)
  }, [value, min, max])

  return (
    <div className="relative w-40">
      <input
        ref={inputRef}
        className="text-theme-sm shadow-theme-xs w-full rounded-lg border border-gray-300 bg-white py-2 pr-4 pl-11 font-medium text-gray-700 focus:ring-0 focus:outline-hidden"
        placeholder={placeholder ?? 'Pilih tanggal'}
        readOnly
      />
      <div className="pointer-events-none absolute inset-0 right-auto left-4 flex items-center">
        <svg
          className="fill-gray-700 dark:fill-gray-400"
          width="20"
          height="20"
          viewBox="0 0 20 20"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path
            fillRule="evenodd"
            clipRule="evenodd"
            d="M6.66683 1.54199C7.08104 1.54199 7.41683 1.87778 7.41683 2.29199V3.00033H12.5835V2.29199C12.5835 1.87778 12.9193 1.54199 13.3335 1.54199C13.7477 1.54199 14.0835 1.87778 14.0835 2.29199V3.00033L15.4168 3.00033C16.5214 3.00033 17.4168 3.89576 17.4168 5.00033V7.50033V15.8337C17.4168 16.9382 16.5214 17.8337 15.4168 17.8337H4.5835C3.47893 17.8337 2.5835 16.9382 2.5835 15.8337V7.50033V5.00033C2.5835 3.89576 3.47893 3.00033 4.5835 3.00033L5.91683 3.00033V2.29199C5.91683 1.87778 6.25262 1.54199 6.66683 1.54199ZM6.66683 4.50033H4.5835C4.30735 4.50033 4.0835 4.72418 4.0835 5.00033V6.75033H15.9168V5.00033C15.9168 4.72418 15.693 4.50033 15.4168 4.50033H13.3335H6.66683ZM15.9168 8.25033H4.0835V15.8337C4.0835 16.1098 4.30735 16.3337 4.5835 16.3337H15.4168C15.693 16.3337 15.9168 16.1098 15.9168 15.8337V8.25033Z"
            fill=""
          />
        </svg>
      </div>
    </div>
  )
}
