/** Rent A Ride mark: a stylised "R" in a royal→cyan tile. */
export function Logo({ size = 34 }: { size?: number }) {
  return (
    <div
      className="grid place-items-center rounded-xl bg-gradient-to-br from-royal to-cyan font-bold text-white shadow-lg shadow-royal/30"
      style={{ width: size, height: size, fontSize: size * 0.55 }}
    >
      R
    </div>
  );
}
