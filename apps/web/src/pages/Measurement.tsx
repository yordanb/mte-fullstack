// Placeholder untuk menu Measurement.
// Konten input data akan diisi sesuai kriteria yang belum didefinisikan.

export default function MeasurementPage() {
  return (
    <div className="mx-auto max-w-7xl">
      <div className="mb-4">
        <h2 className="text-theme-xl font-semibold">Measurement</h2>
        <p className="mt-1 text-theme-sm text-gray-500">
          Catatan hasil pengukuran
        </p>
      </div>

      <div className="rounded-2xl border border-gray-200 bg-white p-10 text-center dark:border-gray-700 dark:bg-gray-900">
        <svg className="mx-auto h-12 w-12 text-gray-300" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
          <path d="M3 7v10a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V7" />
          <path d="M3 7l9 6 9-6" />
          <path d="M9 17V9M15 17v-8" />
        </svg>
        <p className="mt-3 text-theme-sm text-gray-500">
          Konten Measurement akan diisi sesuai kriteria yang akan didefinisikan.
        </p>
      </div>
    </div>
  )
}