export function StatsPanel() {
  const [stats, setStats] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const response = await fetch("/api/stats");
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        const data = await response.json();
        setStats(data);
        setError(null);
        setLoading(false);
      } catch (error) {
        console.error("Failed to fetch stats:", error);
        setError(
          error instanceof Error
            ? error.message
            : "統計データの取得に失敗しました"
        );
        setLoading(false);
      }
    };

    fetchStats();
    const interval = setInterval(fetchStats, 2000); // 2秒ごとに更新

    return () => clearInterval(interval);
  }, []);

  if (loading) {
    return (
      <div
        style={{
          padding: 32,
          background: "linear-gradient(135deg, #1e3c72 0%, #2a5298 100%)",
          borderRadius: 16,
          color: "white",
          textAlign: "center",
          boxShadow: "0 8px 32px rgba(0,0,0,0.3)",
        }}
      >
        <div style={{ fontSize: 18, fontWeight: 600 }}>
          統計データ読み込み中...
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div
        style={{
          padding: 32,
          background: "linear-gradient(135deg, #d32f2f 0%, #f57c00 100%)",
          borderRadius: 16,
          color: "white",
          textAlign: "center",
          boxShadow: "0 8px 32px rgba(0,0,0,0.3)",
        }}
      >
        <div style={{ fontSize: 18, fontWeight: 600 }}>
          ⚠️ エラーが発生しました
        </div>
        <div style={{ fontSize: 14, opacity: 0.8, marginTop: 8 }}>{error}</div>
      </div>
    );
  }

  return (
    <div
      style={{
        padding: 32,
        background: "linear-gradient(135deg, #1e3c72 0%, #2a5298 100%)",
        borderRadius: 16,
        color: "white",
        minWidth: 400,
        boxShadow: "0 8px 32px rgba(0,0,0,0.3)",
      }}
    >
      <h2
        style={{
          margin: "0 0 24px 0",
          fontSize: 28,
          fontWeight: 900,
          textAlign: "center",
          background: "linear-gradient(135deg, #ffd89b 0%, #19547b 100%)",
          WebkitBackgroundClip: "text",
          WebkitTextFillColor: "transparent",
        }}
      >
        📊 リアルタイム統計
      </h2>

      {/* 色の変更統計 */}
      <div style={{ marginBottom: 24 }}>
        <h3
          style={{
            fontSize: 20,
            fontWeight: 700,
            marginBottom: 16,
            color: "#ffd89b",
          }}
        >
          🎨 色別変更回数
        </h3>
        <div
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fit, minmax(120px, 1fr))",
            gap: 12,
          }}
        >
          {stats?.colorStats
            ?.filter((item: any) => item.row)
            ?.map((item: any, index: number) => (
              <div
                key={index}
                style={{
                  padding: 16,
                  background: "rgba(255,255,255,0.1)",
                  borderRadius: 12,
                  textAlign: "center",
                  border: "1px solid rgba(255,255,255,0.2)",
                }}
              >
                <div
                  style={{
                    fontSize: 24,
                    fontWeight: 900,
                    color: item.row.columns[0] || "#fff",
                  }}
                >
                  {item.row.columns[1] || 0}
                </div>
                <div
                  style={{
                    fontSize: 14,
                    opacity: 0.8,
                    textTransform: "uppercase",
                    marginTop: 4,
                  }}
                >
                  {item.row.columns[0] || "unknown"}
                </div>
              </div>
            )) || (
            <div style={{ color: "#ffd89b", fontStyle: "italic" }}>
              統計データなし
            </div>
          )}
        </div>
      </div>

      {/* 最新更新情報 */}
      <div>
        <h3
          style={{
            fontSize: 20,
            fontWeight: 700,
            marginBottom: 16,
            color: "#ffd89b",
          }}
        >
          ⚡ 最新状態
        </h3>
        {stats?.latestUpdates?.find((item: any) => item.row) ? (
          <div
            style={{
              padding: 20,
              background: "rgba(255,255,255,0.1)",
              borderRadius: 12,
              border: "1px solid rgba(255,255,255,0.2)",
            }}
          >
            <div
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
              }}
            >
              <div>
                <div style={{ fontSize: 18, fontWeight: 700 }}>
                  {
                    stats.latestUpdates.find((item: any) => item.row)?.row
                      .columns[0]
                  }
                </div>
                <div
                  style={{
                    fontSize: 24,
                    fontWeight: 900,
                    color: "#ffd89b",
                    marginTop: 4,
                  }}
                >
                  {stats.latestUpdates
                    .find((item: any) => item.row)
                    ?.row.columns[1]?.toUpperCase()}
                </div>
              </div>
              <div style={{ textAlign: "right", opacity: 0.8, fontSize: 14 }}>
                現在の色
              </div>
            </div>
          </div>
        ) : (
          <div style={{ color: "#ffd89b", fontStyle: "italic" }}>
            更新情報なし
          </div>
        )}
      </div>

      <div
        style={{
          marginTop: 20,
          textAlign: "center",
          fontSize: 12,
          opacity: 0.6,
        }}
      >
        最終取得:{" "}
        {stats?.timestamp ? new Date(stats.timestamp).toLocaleTimeString() : ""}
      </div>
    </div>
  );
}

// React Hooksのimportを追加
import { useEffect, useState } from "react";
