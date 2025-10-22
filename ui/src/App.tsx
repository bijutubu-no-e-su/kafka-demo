import { PanelCard } from "./components/PanelCard";
import { StatsPanel } from "./components/StatsPanel";
import { usePanelColor } from "./hooks/usePanelColor";

export default function App() {
  const a = usePanelColor("a");
  const b = usePanelColor("b");
  const c = usePanelColor("c");
  const d = usePanelColor("d");

  return (
    <div
      style={{
        minHeight: "100dvh",
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        background: "#111",
        color: "#eee",
        fontFamily: "system-ui, sans-serif",
        gap: 48,
      }}
    >
      <h1
        style={{
          fontSize: 128,
          fontWeight: 900,
          margin: 0,
          background: "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
          WebkitBackgroundClip: "text",
          WebkitTextFillColor: "transparent",
          textAlign: "center",
        }}
      >
        DEMO
      </h1>
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(4, 320px)",
          gap: 48,
        }}
      >
        <PanelCard label="a_panel" color={a} />
        <PanelCard label="b_panel" color={b} />
        <PanelCard label="c_panel" color={c} />
        <PanelCard label="d_panel" color={d} />
      </div>

      <StatsPanel />
    </div>
  );
}
