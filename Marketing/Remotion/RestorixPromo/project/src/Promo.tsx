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
        src={staticFile("generated/homelab-workbench.png")}
        style={{
          width: "100%",
          height: "100%",
          objectFit: "cover",
          scale: interpolate(frame, [0, durationInFrames], [1.01, 1.05], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      />
      <AbsoluteFill
        style={{
          background:
            "linear-gradient(90deg, rgba(6,10,13,0.96) 0%, rgba(6,10,13,0.82) 42%, rgba(6,10,13,0.18) 76%, rgba(6,10,13,0.28) 100%)",
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
          备份跑完了。
          <br />
          恢复前，先检查。
        </div>
        <div
          style={{
            color: COLORS.muted,
            fontSize: 42,
            lineHeight: 1.45,
            width: 820,
          }}
        >
          检查 Docker volume 的快照覆盖
          <br />
          并确认快照时间
        </div>
      </div>
    </AbsoluteFill>
  );
};

const CompareScene: React.FC<SceneProps> = ({durationInFrames}) => {
  const frame = useCurrentFrame();
  const checks = ["路径", "快照主机名", "时间"];
  return (
    <AbsoluteFill
      style={{
        backgroundColor: COLORS.background,
        opacity: sceneOpacity(frame, durationInFrames),
      }}
    >
      <div
        style={{
          position: "absolute",
          left: 110,
          right: 110,
          top: 92,
          display: "flex",
          flexDirection: "column",
          gap: 18,
        }}
      >
        <Eyebrow>检查过程</Eyebrow>
        <div
          style={{
            color: COLORS.text,
            fontSize: 76,
            lineHeight: 1.08,
            fontWeight: 740,
            letterSpacing: -3,
          }}
        >
          当前 volume 和最近快照，逐项核对
        </div>
      </div>
      <div
        style={{
          position: "absolute",
          left: 150,
          right: 150,
          top: 340,
          display: "grid",
          gridTemplateColumns: "1fr 410px 1fr",
          alignItems: "center",
          gap: 54,
        }}
      >
        <div
          style={{
            minHeight: 330,
            padding: "58px 54px",
            border: `1px solid ${COLORS.line}`,
            borderRadius: 30,
            display: "flex",
            flexDirection: "column",
            justifyContent: "center",
            gap: 28,
            backgroundColor: COLORS.panel,
          }}
        >
          <HardDrives size={68} weight="duotone" color={COLORS.teal} />
          <div style={{color: COLORS.text, fontSize: 48, fontWeight: 700}}>
            Docker volumes
          </div>
          <div style={{color: COLORS.muted, fontSize: 31, lineHeight: 1.45}}>
            读取当前 Mac 上的 volume 列表
          </div>
        </div>
        <div style={{display: "flex", flexDirection: "column", gap: 22}}>
          {checks.map((check, index) => (
            <div
              key={check}
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                gap: 18,
                color: COLORS.text,
                fontSize: 31,
                opacity: interpolate(frame, [28 + index * 12, 52 + index * 12], [0, 1], {
                  extrapolateLeft: "clamp",
                  extrapolateRight: "clamp",
                }),
              }}
            >
              <span style={{color: COLORS.muted}}>检查</span>
              <span style={{fontWeight: 700}}>{check}</span>
              <span style={{color: COLORS.teal}}>→</span>
            </div>
          ))}
        </div>
        <div
          style={{
            minHeight: 330,
            padding: "58px 54px",
            border: `1px solid ${COLORS.line}`,
            borderRadius: 30,
            display: "flex",
            flexDirection: "column",
            justifyContent: "center",
            gap: 28,
            backgroundColor: COLORS.panel,
          }}
        >
          <Database size={68} weight="duotone" color={COLORS.amber} />
          <div style={{color: COLORS.text, fontSize: 48, fontWeight: 700}}>
            restic snapshots
          </div>
          <div style={{color: COLORS.muted, fontSize: 31, lineHeight: 1.45}}>
            查找对应且足够新的快照
          </div>
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
        <Eyebrow>首页</Eyebrow>
        <div
          style={{
            color: COLORS.text,
            fontSize: 82,
            lineHeight: 1.08,
            fontWeight: 750,
            letterSpacing: -3,
          }}
        >
          每个状态
          <br />
          分开看。
        </div>
        <div style={{color: COLORS.muted, fontSize: 36, lineHeight: 1.48}}>
          受保护、未保护、已过期、未知与错误，以及 Docker 和 restic 的连接情况。
        </div>
      </div>
      <ScreenshotFrame src="screenshots/dashboard-health.png" width={1210} rotate={-1.2} />
    </AbsoluteFill>
  );
};

const BoundaryScene: React.FC<SceneProps> = ({durationInFrames}) => {
  const frame = useCurrentFrame();
  const facts = [
    {icon: Database, text: "沿用现有 restic 仓库与备份流程"},
    {icon: ShieldCheck, text: "读取当前状态并检查快照覆盖"},
    {icon: FileText, text: "把检查结果留在本机"},
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
        <Eyebrow>分工</Eyebrow>
        <div
          style={{
            color: COLORS.text,
            fontSize: 78,
            lineHeight: 1.08,
            fontWeight: 750,
            letterSpacing: -3,
          }}
        >
          备份照常运行。
          <br />
          Restorix 负责检查。
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
          <Eyebrow>仓库设置</Eyebrow>
          <div
            style={{
              color: COLORS.text,
              fontSize: 76,
              fontWeight: 750,
              letterSpacing: -3,
            }}
          >
            连接现有 restic 仓库
          </div>
        </div>
        <div style={{color: COLORS.muted, fontSize: 31, maxWidth: 640, lineHeight: 1.42}}>
          可指定预期快照主机名，并在本机测试连接。密码继续由环境变量与 macOS 钥匙串管理。
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
        <Eyebrow>报告</Eyebrow>
        <div
          style={{
            color: COLORS.text,
            fontSize: 66,
            lineHeight: 1.08,
            fontWeight: 750,
            letterSpacing: -3,
          }}
        >
          扫描结果
          <br />
          可以直接保存
        </div>
        <div style={{color: COLORS.muted, fontSize: 34, lineHeight: 1.46}}>
          Markdown 报告会保留状态、原因和恢复提示，便于巡检留档与团队交接。
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
        <Eyebrow>日常使用</Eyebrow>
        <div
          style={{
            color: COLORS.text,
            fontSize: 78,
            lineHeight: 1.08,
            fontWeight: 750,
            letterSpacing: -3,
          }}
        >
          菜单栏里
          <br />
          快速看状态。
        </div>
        <div style={{color: COLORS.muted, fontSize: 33, lineHeight: 1.48}}>
          过期阈值、界面语言与图标都能调整。SwiftUI 界面和 Rust Core 使用同一套判断逻辑。
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
        src={staticFile("generated/homelab-workbench.png")}
        style={{
          width: "100%",
          height: "100%",
          objectFit: "cover",
          scale: interpolate(frame, [0, durationInFrames], [1.04, 1.01], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      />
      <AbsoluteFill
        style={{
          background:
            "linear-gradient(90deg, rgba(6,10,13,0.97) 0%, rgba(6,10,13,0.88) 50%, rgba(6,10,13,0.34) 100%)",
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
          恢复前，先查一遍。
        </div>
        <div style={{color: COLORS.muted, fontSize: 36, lineHeight: 1.48}}>
          {tagline}
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

      <Sequence durationInFrames={293}>
        <OpeningScene durationInFrames={293} />
      </Sequence>
      <Sequence from={293} durationInFrames={393}>
        <CompareScene durationInFrames={393} />
      </Sequence>
      <Sequence from={686} durationInFrames={323}>
        <DashboardScene durationInFrames={323} />
      </Sequence>
      <Sequence from={1009} durationInFrames={303}>
        <BoundaryScene durationInFrames={303} />
      </Sequence>
      <Sequence from={1312} durationInFrames={354}>
        <RepositoryScene durationInFrames={354} />
      </Sequence>
      <Sequence from={1666} durationInFrames={301}>
        <ReportScene durationInFrames={301} />
      </Sequence>
      <Sequence from={1967} durationInFrames={337}>
        <NativeScene durationInFrames={337} />
      </Sequence>
      <Sequence from={2304} durationInFrames={171}>
        <ClosingScene
          durationInFrames={171}
          title={title}
          tagline={tagline}
        />
      </Sequence>

      <CaptionOverlay />
    </AbsoluteFill>
  );
};
