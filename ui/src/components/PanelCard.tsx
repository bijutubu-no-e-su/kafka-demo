export function PanelCard({ label, color }: { label: string; color: string }) {
  return (
    <div
      style={{ display: "flex", flexDirection: "column", alignItems: "center" }}
    >
      <div
        style={{
          width: 320,
          height: 320,
          borderRadius: 24,
          boxShadow: "0 16px 48px rgba(0,0,0,.5)",
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          fontWeight: 700,
          fontSize: 36,
          color: "#111",
          background: color || "gray",
        }}
      >
        {(color || "gray").toUpperCase()}
      </div>
      <div
        style={{ marginTop: 20, color: "#888", fontSize: 48, fontWeight: 700 }}
      >
        {label}
      </div>
    </div>
  );
}
