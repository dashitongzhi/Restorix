import type {Caption} from "@remotion/captions";
import {Audio} from "@remotion/media";
import {
  Database,
  FileText,
  HardDrives,
  ShieldCheck,
} from "@phosphor-icons/react";
import {
  AbsoluteFill,
  Easing,
  Img,
  Sequence,
  interpolate,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import captionsJson from "../public/captions/narration.json";

type PromoProps = {
  title: string;
  tagline: string;
};

type SceneProps = {
  durationInFrames: number;
};

const captions = captionsJson as Caption[];

const COLORS = {
  background: "#0a0f13",
  panel: "#11191f",
  text: "#f4f7f8",
  muted: "#aab5bb",
  teal: "#2fc6c3",
  amber: "#d99b45",
  line: "rgba(255,255,255,0.12)",
};

const sceneOpacity = (frame: number, durationInFrames: number) =>
  interpolate(
    frame,
    [0, 18, Math.max(19, durationInFrames - 18), durationInFrames],
    [0, 1, 1, 0],
    {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
      easing: Easing.bezier(0.16, 1, 0.3, 1),
    },
  );

const Eyebrow: React.FC<{children: React.ReactNode}> = ({children}) => (
  <div
    style={{
      color: COLORS.teal,
      fontSize: 28,
      fontWeight: 700,
      letterSpacing: 2,
      textTransform: "uppercase",
    }}
  >
    {children}
  </div>
);

const ScreenshotFrame: React.FC<{
  src: string;
  width: number;
  rotate?: number;
  translateY?: number;
}> = ({src, width, rotate = 0, translateY = 0}) => {
  const frame = useCurrentFrame();
  return (
    <div
      style={{
        width,
        overflow: "hidden",
        borderRadius: 34,
        border: `1px solid ${COLORS.line}`,
        backgroundColor: "rgba(6,10,13,0.86)",
        boxShadow: "0 45px 110px rgba(0,0,0,0.46)",
        opacity: interpolate(frame, [8, 30], [0, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
          easing: Easing.bezier(0.16, 1, 0.3, 1),
        }),
        scale: interpolate(frame, [0, 80], [0.94, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
          easing: Easing.bezier(0.16, 1, 0.3, 1),
        }),
        translate: `0 ${interpolate(frame, [0, 80], [translateY + 32, translateY], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
          easing: Easing.bezier(0.16, 1, 0.3, 1),
        })}px`,
        rotate: `${rotate}deg`,
      }}
    >
      <Img
        src={staticFile(src)}
        style={{
          display: "block",
          width: "100%",
          height: "auto",
        }}
      />
    </div>
  );
};

const OpeningScene: React.FC<SceneProps> = ({durationInFrames}) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{opacity: sceneOpacity(frame, durationInFrames)}}>
      <Img
        src={staticFile("generated/data-vault.png")}
        style={{
          width: "100%",
          height: "100%",
          objectFit: "cover",
          scale: interpolate(frame, [0, durationInFrames], [1.02, 1.09], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      />
      <AbsoluteFill
        style={{
          background:
            "linear-gradient(90deg, rgba(6,10,13,0.98) 0%, rgba(6,10,13,0.86) 38%, rgba(6,10,13,0.18) 72%, rgba(6,10,13,0.42) 100%)",
        }}
      />
      <div
        style={{
          position: "absolute",
          left: 120,
          top: 170,
          width: 940,
          display: "flex",
          flexDirection: "column",
          gap: 34,
          opacity: interpolate(frame, [10, 42], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          translate: `0 ${interpolate(frame, [10, 42], [34, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          })}px`,
        }}
      >
        <Eyebrow>Restorix for macOS</Eyebrow>
        <div
          style={{
            color: COLORS.text,
            fontSize: 112,
            fontWeight: 760,
            lineHeight: 1.04,
            letterSpacing: -5,
          }}
        >
          备份运行过。
          <br />
          真的可恢复吗？
        </div>
        <div
          style={{
            color: COLORS.muted,
            fontSize: 42,
            lineHeight: 1.45,
            width: 820,
          }}
        >
          面向自托管 Docker volumes 的备份可信度检查器
        </div>
      </div>
    </AbsoluteFill>
  );
};

const CompareScene: React.FC<SceneProps> = ({durationInFrames}) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill
      style={{
        backgroundColor: COLORS.background,
        opacity: sceneOpacity(frame, durationInFrames),
      }}
    >
      <Img
        src={staticFile("generated/volume-snapshot-map.png")}
        style={{
          width: "100%",
          height: "100%",
          objectFit: "cover",
          opacity: 0.74,
          scale: interpolate(frame, [0, durationInFrames], [1.04, 1.1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      />
      <AbsoluteFill
        style={{
          background:
            "linear-gradient(180deg, rgba(8,12,15,0.78) 0%, rgba(8,12,15,0.05) 45%, rgba(8,12,15,0.74) 100%)",
        }}
      />
      <div
        style={{
          position: "absolute",
          left: 110,
          right: 110,
          top: 92,
          display: "flex",
          alignItems: "flex-start",
          justifyContent: "space-between",
          gap: 80,
        }}
      >
        <div style={{display: "flex", flexDirection: "column", gap: 20}}>
          <Eyebrow>真实状态比对</Eyebrow>
          <div
            style={{
              color: COLORS.text,
              fontSize: 78,
              lineHeight: 1.08,
              fontWeight: 740,
              letterSpacing: -3,
              maxWidth: 1020,
            }}
          >
            逐卷核对路径、主机名与时间阈值
          </div>
        </div>
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 18,
            padding: "18px 24px",
            borderRadius: 18,
            border: `1px solid ${COLORS.line}`,
            backgroundColor: "rgba(9,15,19,0.72)",
            color: COLORS.text,
            fontSize: 30,
            fontWeight: 650,
          }}
        >
          <HardDrives size={38} weight="duotone" color={COLORS.teal} />
          Docker volumes
          <span style={{color: COLORS.muted}}>→</span>
          restic snapshots
        </div>
      </div>
    </AbsoluteFill>
  );
};

const DashboardScene: React.FC<SceneProps> = ({durationInFrames}) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill
      style={{
        background:
          "radial-gradient(circle at 75% 42%, rgba(47,198,195,0.1), transparent 30%), #0a0f13",
        opacity: sceneOpacity(frame, durationInFrames),
        padding: "100px 110px 150px",
        display: "grid",
        gridTemplateColumns: "520px 1fr",
        alignItems: "center",
        gap: 72,
      }}
    >
      <div style={{display: "flex", flexDirection: "column", gap: 26}}>
        <Eyebrow>一眼看到风险</Eyebrow>
        <div
          style={{
            color: COLORS.text,
            fontSize: 82,
            lineHeight: 1.08,
            fontWeight: 750,
            letterSpacing: -3,
          }}
        >
          状态清楚。
          <br />
          原因也清楚。
        </div>
        <div style={{color: COLORS.muted, fontSize: 36, lineHeight: 1.48}}>
          Protected、Unprotected、Stale、Unknown 与 Error，使用同一套健康模型。
        </div>
      </div>
      <ScreenshotFrame src="screenshots/dashboard-health.png" width={1210} rotate={-1.2} />
    </AbsoluteFill>
  );
};

const BoundaryScene: React.FC<SceneProps> = ({durationInFrames}) => {
  const frame = useCurrentFrame();
  const facts = [
    {icon: Database, text: "扫描 Docker 与 restic 的真实状态"},
    {icon: ShieldCheck, text: "验证最近快照是否覆盖 volume"},
    {icon: FileText, text: "给出原因、风险与下一步动作"},
  ];
  return (
    <AbsoluteFill
      style={{
        backgroundColor: COLORS.background,
        opacity: sceneOpacity(frame, durationInFrames),
        padding: "100px 110px 150px",
        display: "grid",
        gridTemplateColumns: "610px 1fr",
        alignItems: "center",
        gap: 56,
      }}
    >
      <div style={{display: "flex", flexDirection: "column", gap: 30}}>
        <Eyebrow>产品边界</Eyebrow>
        <div
          style={{
            color: COLORS.text,
            fontSize: 78,
            lineHeight: 1.08,
            fontWeight: 750,
            letterSpacing: -3,
          }}
        >
          不是备份工具。
          <br />
          是独立验证层。
        </div>
        <div style={{display: "flex", flexDirection: "column", gap: 18}}>
          {facts.map(({icon: Icon, text}, index) => (
            <div
              key={text}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 18,
                color: index === 1 ? COLORS.text : COLORS.muted,
                fontSize: 31,
                lineHeight: 1.35,
                opacity: interpolate(frame, [24 + index * 12, 48 + index * 12], [0, 1], {
                  extrapolateLeft: "clamp",
                  extrapolateRight: "clamp",
                }),
              }}
            >
              <Icon size={38} color={index === 1 ? COLORS.teal : COLORS.muted} weight="duotone" />
              {text}
            </div>
          ))}
        </div>
      </div>
      <ScreenshotFrame src="screenshots/volumes-empty.png" width={1120} rotate={1.1} />
    </AbsoluteFill>
  );
};

const RepositoryScene: React.FC<SceneProps> = ({durationInFrames}) => {
  const frame = useCurrentFrame();
  const switchFrame = 209;
  return (
    <AbsoluteFill
      style={{
        background:
          "radial-gradient(circle at 50% 30%, rgba(217,155,69,0.08), transparent 30%), #0a0f13",
        opacity: sceneOpacity(frame, durationInFrames),
        padding: "90px 110px 150px",
        display: "flex",
        flexDirection: "column",
        gap: 34,
      }}
    >
      <div
        style={{
          display: "flex",
          alignItems: "flex-end",
          justifyContent: "space-between",
          gap: 80,
        }}
      >
        <div style={{display: "flex", flexDirection: "column", gap: 18}}>
          <Eyebrow>仓库与凭据</Eyebrow>
          <div
            style={{
              color: COLORS.text,
              fontSize: 76,
              fontWeight: 750,
              letterSpacing: -3,
            }}
          >
            配置仓库。保留凭据边界。
          </div>
        </div>
        <div style={{color: COLORS.muted, fontSize: 31, maxWidth: 640, lineHeight: 1.42}}>
          指定预期快照主机名。本地测试连接，密码由环境变量与 macOS 钥匙串管理。
        </div>
      </div>
      <div
        style={{
          position: "relative",
          flex: 1,
          display: "flex",
          alignItems: "flex-start",
          justifyContent: "center",
        }}
      >
        <div
          style={{
            position: "absolute",
            opacity: interpolate(frame, [switchFrame - 20, switchFrame + 10], [1, 0], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
          }}
        >
          <ScreenshotFrame
            src="screenshots/repositories-empty.png"
            width={1120}
            translateY={22}
          />
        </div>
        <div
          style={{
            position: "absolute",
            opacity: interpolate(frame, [switchFrame - 5, switchFrame + 28], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
          }}
        >
          <ScreenshotFrame
            src="screenshots/settings-icons.png"
            width={1120}
            translateY={22}
          />
        </div>
      </div>
    </AbsoluteFill>
  );
};

const ReportScene: React.FC<SceneProps> = ({durationInFrames}) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill
      style={{
        backgroundColor: COLORS.background,
        opacity: sceneOpacity(frame, durationInFrames),
        padding: "90px 110px 150px",
        display: "grid",
        gridTemplateColumns: "1050px 1fr",
        alignItems: "center",
        gap: 70,
      }}
    >
      <ScreenshotFrame src="screenshots/report-empty.png" width={1050} rotate={-0.8} />
      <div style={{display: "flex", flexDirection: "column", gap: 26}}>
        <Eyebrow>Markdown 报告</Eyebrow>
        <div
          style={{
            color: COLORS.text,
            fontSize: 66,
            lineHeight: 1.08,
            fontWeight: 750,
            letterSpacing: -3,
          }}
        >
          审计、记录、交接，都有同一份证据。
        </div>
        <div style={{color: COLORS.muted, fontSize: 34, lineHeight: 1.46}}>
          复制或保存报告，把风险、原因与恢复提示带进实际运维流程。
        </div>
      </div>
    </AbsoluteFill>
  );
};

const NativeScene: React.FC<SceneProps> = ({durationInFrames}) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill
      style={{
        background:
          "radial-gradient(circle at 30% 40%, rgba(47,198,195,0.1), transparent 28%), #0a0f13",
        opacity: sceneOpacity(frame, durationInFrames),
        padding: "90px 110px 150px",
        display: "grid",
        gridTemplateColumns: "470px 1fr",
        alignItems: "center",
        gap: 70,
      }}
    >
      <div style={{display: "flex", flexDirection: "column", gap: 26}}>
        <Eyebrow>macOS 原生体验</Eyebrow>
        <div
          style={{
            color: COLORS.text,
            fontSize: 78,
            lineHeight: 1.08,
            fontWeight: 750,
            letterSpacing: -3,
          }}
        >
          界面可配置。
          <br />
          核心保持一致。
        </div>
        <div style={{color: COLORS.muted, fontSize: 33, lineHeight: 1.48}}>
          简体中文、菜单栏状态、过期阈值与多套图标。SwiftUI 与 Rust Core 共享同一健康模型。
        </div>
      </div>
      <ScreenshotFrame src="screenshots/settings-icons.png" width={1240} rotate={0.9} />
    </AbsoluteFill>
  );
};

const ClosingScene: React.FC<SceneProps & PromoProps> = ({
  durationInFrames,
  title,
  tagline,
}) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{opacity: sceneOpacity(frame, durationInFrames)}}>
      <Img
        src={staticFile("generated/data-vault.png")}
        style={{
          width: "100%",
          height: "100%",
          objectFit: "cover",
          scale: interpolate(frame, [0, durationInFrames], [1.08, 1.03], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      />
      <AbsoluteFill
        style={{
          background:
            "linear-gradient(90deg, rgba(6,10,13,0.98) 0%, rgba(6,10,13,0.88) 48%, rgba(6,10,13,0.46) 100%)",
        }}
      />
      <div
        style={{
          position: "absolute",
          left: 120,
          top: 160,
          width: 980,
          display: "flex",
          flexDirection: "column",
          gap: 30,
        }}
      >
        <Img
          src={staticFile("brand/restorix-icon.png")}
          style={{
            width: 210,
            height: 210,
            borderRadius: 48,
            boxShadow: "0 28px 90px rgba(0,0,0,0.45)",
            opacity: interpolate(frame, [10, 38], [0, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
            scale: interpolate(frame, [10, 55], [0.82, 1], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            }),
          }}
        />
        <div
          style={{
            color: COLORS.text,
            fontSize: 106,
            fontWeight: 770,
            letterSpacing: -5,
          }}
        >
          {title}
        </div>
        <div
          style={{
            color: COLORS.text,
            fontSize: 56,
            fontWeight: 650,
            lineHeight: 1.2,
          }}
        >
          先验证，再信任恢复。
        </div>
        <div style={{color: COLORS.muted, fontSize: 36, lineHeight: 1.48}}>
          {tagline}
        </div>
        <div style={{display: "flex", gap: 20, marginTop: 10}}>
          {["有证据", "可解释", "可行动"].map((item, index) => (
            <div
              key={item}
              style={{
                padding: "14px 22px",
                borderRadius: 14,
                border: `1px solid ${index === 1 ? "rgba(47,198,195,0.54)" : COLORS.line}`,
                backgroundColor: "rgba(10,15,19,0.72)",
                color: index === 1 ? COLORS.teal : COLORS.text,
                fontSize: 28,
                fontWeight: 650,
              }}
            >
              {item}
            </div>
          ))}
        </div>
      </div>
    </AbsoluteFill>
  );
};

const CaptionOverlay: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const now = (frame / fps) * 1000;
  const active = captions.find(
    (caption) => now >= caption.startMs && now <= caption.endMs,
  );
  if (!active) {
    return null;
  }

  return (
    <div
      style={{
        position: "absolute",
        left: 190,
        right: 190,
        bottom: 42,
        display: "flex",
        justifyContent: "center",
        pointerEvents: "none",
      }}
    >
      <div
        style={{
          maxWidth: 1500,
          padding: "18px 34px 20px",
          borderRadius: 18,
          border: "1px solid rgba(255,255,255,0.14)",
          backgroundColor: "rgba(4,8,11,0.84)",
          color: "#ffffff",
          fontSize: 38,
          lineHeight: 1.35,
          fontWeight: 600,
          textAlign: "center",
          boxShadow: "0 18px 50px rgba(0,0,0,0.3)",
        }}
      >
        {active.text}
      </div>
    </div>
  );
};

export const RestorixPromo: React.FC<PromoProps> = ({title, tagline}) => {
  return (
    <AbsoluteFill
      style={{
        backgroundColor: COLORS.background,
        fontFamily:
          '-apple-system, BlinkMacSystemFont, "SF Pro Display", "PingFang SC", "Helvetica Neue", sans-serif',
      }}
    >
      <Audio src={staticFile("audio/ambient.m4a")} volume={0.78} />
      <Audio src={staticFile("audio/narration.mp3")} volume={1} />

      <Sequence durationInFrames={326}>
        <OpeningScene durationInFrames={326} />
      </Sequence>
      <Sequence from={326} durationInFrames={414}>
        <CompareScene durationInFrames={414} />
      </Sequence>
      <Sequence from={740} durationInFrames={356}>
        <DashboardScene durationInFrames={356} />
      </Sequence>
      <Sequence from={1096} durationInFrames={373}>
        <BoundaryScene durationInFrames={373} />
      </Sequence>
      <Sequence from={1469} durationInFrames={341}>
        <RepositoryScene durationInFrames={341} />
      </Sequence>
      <Sequence from={1810} durationInFrames={375}>
        <ReportScene durationInFrames={375} />
      </Sequence>
      <Sequence from={2185} durationInFrames={350}>
        <NativeScene durationInFrames={350} />
      </Sequence>
      <Sequence from={2535} durationInFrames={345}>
        <ClosingScene
          durationInFrames={345}
          title={title}
          tagline={tagline}
        />
      </Sequence>

      <CaptionOverlay />
    </AbsoluteFill>
  );
};
