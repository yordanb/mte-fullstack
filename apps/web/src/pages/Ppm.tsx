// Placeholder untuk menu PPM (Planned Preventive Maintenance).
// Konten input data akan diisi sesuai kriteria yang belum didefinisikan.

export default function PpmPage() {
  return (
    <div className="mx-auto max-w-7xl">
      <div className="mb-4">
        <h2 className="text-theme-xl font-semibold">PPM</h2>
        <p className="mt-1 text-theme-sm text-gray-500">
          Planned Preventive Maintenance
        </p>
      </div>

      <div className="rounded-2xl border border-gray-200 bg-white p-10 text-center dark:border-gray-700 dark:bg-gray-900">
        <svg className="mx-auto h-12 w-12 text-gray-300" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
          <path d="M9 11l3 3L22 4M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11" />
        </svg>
        <p className="mt-3 text-theme-sm text-gray-500">
          Konten PPM akan diisi sesuai kriteria yang akan didefinisikan.
        </p>
      </div>
    </div>
  )
}