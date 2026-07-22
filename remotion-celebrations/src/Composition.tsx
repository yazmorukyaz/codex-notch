import type {CSSProperties} from "react";
import {
  AbsoluteFill,
  Composition,
  interpolate,
  Sequence,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

type CelebrationVariant = "quiet" | "spark" | "confetti" | "allDone";

type CelebrationProps = {
  durationInFrames: number;
  variant: CelebrationVariant;
};

type Particle = {
  angle: number;
  delay: number;
  distance: number;
  length: number;
  bright: boolean;
};

type ConfettiColor = "green" | "white" | "blue";

type ConfettiPiece = {
  color: ConfettiColor;
  delay: number;
  drift: number;
  drop: number;
  height: number;
  lift: number;
  rotation: number;
  width: number;
};

type ScreenConfettiPiece = {
  colorIndex: number;
  delay: number;
  drag: number;
  fan: number;
  frequency: number;
  gravity: number;
  height: number;
  horizontalVelocity: number;
  initialRotation: number;
  phase: number;
  spin: number;
  verticalVelocity: number;
  width: number;
  wobble: number;
};

const FPS = 60;
const WIDTH = 740;
const HEIGHT = 72;
const SCREEN_WIDTH = 1512;
const SCREEN_HEIGHT = 982;
const SCREEN_DURATION = 144;
const GREEN = "#4fc77d";
const BLUE = "#61a8ff";

const quietParticles: Particle[] = [];
const sparkParticles: Particle[] = [
  {angle: -34, delay: 0, distance: 29, length: 12, bright: true},
  {angle: 18, delay: 2, distance: 25, length: 11, bright: false},
  {angle: 72, delay: 1, distance: 22, length: 10, bright: true},
  {angle: 146, delay: 3, distance: 29, length: 12, bright: false},
  {angle: 210, delay: 1, distance: 25, length: 11, bright: true},
  {angle: 326, delay: 3, distance: 29, length: 12, bright: false},
];
const allDoneParticles: Particle[] = [
  ...sparkParticles,
  {angle: 4, delay: 4, distance: 34, length: 9, bright: true},
  {angle: 106, delay: 2, distance: 30, length: 10, bright: false},
  {angle: 184, delay: 5, distance: 34, length: 9, bright: true},
  {angle: 280, delay: 4, distance: 30, length: 10, bright: false},
];
const confettiPieces: ConfettiPiece[] = [
  {color: "green", delay: 0, drift: -68, drop: 15.2, height: 12, lift: 18.8, rotation: -210, width: 4.8},
  {color: "white", delay: 2, drift: -52, drop: 17.6, height: 10, lift: 14.4, rotation: 240, width: 5.6},
  {color: "blue", delay: 1, drift: -36, drop: 12.8, height: 13.6, lift: 20.4, rotation: -180, width: 4.8},
  {color: "green", delay: 5, drift: -20, drop: 16, height: 9.6, lift: 15.2, rotation: 300, width: 5.6},
  {color: "white", delay: 7, drift: -8, drop: 14.4, height: 10.8, lift: 19.2, rotation: -260, width: 4.4},
  {color: "green", delay: 2, drift: 12, drop: 16, height: 12.4, lift: 17.2, rotation: 230, width: 5.2},
  {color: "blue", delay: 6, drift: 24, drop: 12.8, height: 10.4, lift: 20, rotation: -310, width: 4.8},
  {color: "green", delay: 3, drift: 40, drop: 17.6, height: 12.8, lift: 15.2, rotation: 280, width: 5.6},
  {color: "white", delay: 4, drift: 56, drop: 15.2, height: 11.2, lift: 18.4, rotation: -240, width: 4.4},
  {color: "green", delay: 8, drift: 72, drop: 18, height: 10, lift: 13.2, rotation: 320, width: 5.2},
];

const uint32Unit = (eventID: number, index: number, salt: number) => {
  let value =
    (eventID +
      Math.imul(index + 1, 0x9e3779b9) +
      Math.imul(salt + 1, 0x85ebca6b)) >>>
    0;
  value ^= value >>> 16;
  value = Math.imul(value, 0x7feb352d) >>> 0;
  value ^= value >>> 15;
  value = Math.imul(value, 0x846ca68b) >>> 0;
  value ^= value >>> 16;
  return (value >>> 0) / 0xffffffff;
};

const makeScreenConfetti = (
  eventID: number,
  count: number,
): ScreenConfettiPiece[] =>
  Array.from({length: count}, (_, index) => {
    const fanJitter =
      (uint32Unit(eventID, index, 0) - 0.5) * (1.2 / count);
    const fan = Math.min(
      1,
      Math.max(-1, ((index + 0.5) / count) * 2 - 1 + fanJitter),
    );
    const spinDirection = uint32Unit(eventID, index, 9) > 0.5 ? 1 : -1;

    return {
      fan,
      delay: uint32Unit(eventID, index, 1) * 0.18,
      horizontalVelocity: 0.52 + uint32Unit(eventID, index, 2) * 0.18,
      verticalVelocity:
        0.08 + 0.22 * (1 - Math.abs(fan)) + uint32Unit(eventID, index, 3) * 0.08,
      drag: 0.48 + uint32Unit(eventID, index, 4) * 0.2,
      gravity: 0.32 + uint32Unit(eventID, index, 5) * 0.1,
      wobble: 10 + uint32Unit(eventID, index, 6) * 28,
      phase: uint32Unit(eventID, index, 7) * Math.PI * 2,
      frequency: 5 + uint32Unit(eventID, index, 8) * 5,
      initialRotation: uint32Unit(eventID, index, 10) * Math.PI * 2,
      spin:
        spinDirection * (4 + uint32Unit(eventID, index, 11) * 7),
      width: 4 + uint32Unit(eventID, index, 12) * 3,
      height: 8 + uint32Unit(eventID, index, 13) * 7,
      colorIndex: Math.floor(uint32Unit(eventID, index, 14) * 6),
    };
  });

const screenConfettiPieces = makeScreenConfetti(42, 144);
const screenPalette = [
  GREEN,
  BLUE,
  "#fafcff",
  "#ffca57",
  "#d173fa",
  "#ff6e8c",
];

const clamp = {
  extrapolateLeft: "clamp" as const,
  extrapolateRight: "clamp" as const,
};

const shell: CSSProperties = {
  backgroundColor: "#000",
  borderBottomLeftRadius: 36,
  borderBottomRightRadius: 36,
  color: "white",
  fontFamily:
    "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Helvetica Neue', sans-serif",
  overflow: "hidden",
};

const NormalStatus: React.FC<{variant: CelebrationVariant; opacity: number}> = ({
  variant,
  opacity,
}) => {
  const allDone = variant === "allDone";
  return (
    <div
      style={{
        alignItems: "center",
        display: "flex",
        gap: 22,
        inset: 0,
        justifyContent: "center",
        opacity,
        position: "absolute",
      }}
    >
      <div
        style={{
          backgroundColor: "#61a8ff",
          borderRadius: "50%",
          boxShadow: "0 0 24px rgba(97, 168, 255, 0.16)",
          height: 18,
          width: 18,
        }}
      />
      <span
        style={{
          color: "rgba(255,255,255,0.84)",
          fontSize: 42,
          fontVariantNumeric: "tabular-nums",
          fontWeight: 540,
          letterSpacing: -1.1,
          lineHeight: 1,
        }}
      >
        {allDone ? "1 working" : "4 working"}
      </span>
    </div>
  );
};

const SparkField: React.FC<{variant: CelebrationVariant}> = ({variant}) => {
  const frame = useCurrentFrame();
  const particles =
    variant === "allDone"
      ? allDoneParticles
      : variant === "spark"
        ? sparkParticles
        : quietParticles;

  return (
    <>
      {particles.map((particle, index) => {
        const progress = interpolate(
          frame,
          [particle.delay, particle.delay + 24],
          [0, 1],
          clamp,
        );
        const eased = 1 - Math.pow(1 - progress, 3);
        const radians = (particle.angle * Math.PI) / 180;
        const x = Math.cos(radians) * particle.distance * eased;
        const y = Math.sin(radians) * 15 * eased;
        const opacity = interpolate(progress, [0, 0.12, 1], [0, 1, 0], clamp);

        return (
          <div
            key={`${particle.angle}-${index}`}
            style={{
              backgroundColor: particle.bright ? "#fff" : GREEN,
              borderRadius: 99,
              height: particle.length,
              left: "50%",
              opacity,
              position: "absolute",
              top: "50%",
              transform: `translate(${-88 + x}px, ${-particle.length / 2 + y}px) rotate(${particle.angle + 90}deg)`,
              transformOrigin: "center",
              width: 6,
            }}
          />
        );
      })}
    </>
  );
};

const confettiColor = (color: ConfettiColor) => {
  switch (color) {
    case "green":
      return GREEN;
    case "white":
      return "rgba(255,255,255,0.90)";
    case "blue":
      return BLUE;
  }
};

const ConfettiField: React.FC = () => {
  const frame = useCurrentFrame();

  return (
    <>
      {confettiPieces.map((piece, index) => {
        const progress = interpolate(
          frame,
          [piece.delay, piece.delay + 32],
          [0, 1],
          clamp,
        );
        const eased = 1 - Math.pow(1 - progress, 3);
        const x = piece.drift * eased;
        const y =
          -piece.lift * Math.sin(progress * Math.PI) +
          piece.drop * progress * progress;
        const opacity = interpolate(
          progress,
          [0, 0.08, 0.72, 1],
          [0, 1, 1, 0],
          clamp,
        );

        return (
          <div
            key={`${piece.drift}-${index}`}
            style={{
              backgroundColor: confettiColor(piece.color),
              borderRadius: 2,
              height: piece.height,
              left: "50%",
              opacity,
              position: "absolute",
              top: "50%",
              transform: `translate(${-88 + x}px, ${-piece.height / 2 + y}px) rotate(${piece.rotation * progress}deg)`,
              transformOrigin: "center",
              width: piece.width,
            }}
          />
        );
      })}
    </>
  );
};

const Celebration: React.FC<CelebrationProps> = ({
  durationInFrames,
  variant,
}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const overlayOpacity =
    interpolate(frame, [0, 6], [0, 1], clamp) *
    interpolate(
      frame,
      [durationInFrames - 13, durationInFrames - 1],
      [1, 0],
      clamp,
    );
  const checkEntry = spring({
    fps,
    frame: Math.max(0, frame - 4),
    config: {damping: 20, mass: 0.65, stiffness: 210},
    durationInFrames: 22,
  });
  const checkScale = interpolate(checkEntry, [0, 1], [0.62, 1]);
  const glowOpacity =
    interpolate(frame, [4, 12], [0, variant === "allDone" ? 0.18 : 0.12], clamp) *
    interpolate(frame, [28, 52], [1, 0], clamp) *
    overlayOpacity;
  const label = variant === "allDone" ? "All done" : "Finished";

  return (
    <AbsoluteFill style={shell}>
      <NormalStatus variant={variant} opacity={1 - overlayOpacity} />

      <AbsoluteFill style={{backgroundColor: "#000", opacity: overlayOpacity}} />

      <div
        style={{
          background: `radial-gradient(circle, ${GREEN} 0%, rgba(79,199,125,0) 70%)`,
          borderRadius: "50%",
          height: 136,
          left: "50%",
          opacity: glowOpacity,
          position: "absolute",
          top: "50%",
          transform: "translate(-156px, -68px)",
          width: 136,
        }}
      />

      <Sequence from={5} durationInFrames={42} premountFor={30}>
        {variant === "confetti" ? (
          <ConfettiField />
        ) : (
          <SparkField variant={variant} />
        )}
      </Sequence>

      <div
        style={{
          alignItems: "center",
          display: "flex",
          gap: 20,
          inset: 0,
          justifyContent: "center",
          opacity: overlayOpacity,
          position: "absolute",
        }}
      >
        <div
          style={{
            alignItems: "center",
            backgroundColor: GREEN,
            borderRadius: "50%",
            color: "rgba(0,0,0,0.92)",
            display: "flex",
            fontSize: 24,
            fontWeight: 900,
            height: 40,
            justifyContent: "center",
            lineHeight: 1,
            transform: `scale(${checkScale})`,
            width: 40,
          }}
        >
          ✓
        </div>
        <span
          style={{
            color: "rgba(255,255,255,0.92)",
            fontSize: 42,
            fontWeight: 650,
            letterSpacing: -1.1,
            lineHeight: 1,
          }}
        >
          {label}
        </span>
      </div>
    </AbsoluteFill>
  );
};

const ScreenCompletionConfetti: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const elapsed = frame / fps;
  const badgeOpacity =
    interpolate(elapsed, [0.04, 0.2], [0, 1], clamp) *
    interpolate(elapsed, [1.72, 2.22], [1, 0], clamp);
  const badgeEntry = interpolate(elapsed, [0.04, 0.38], [0, 1], clamp);
  const badgeProgress =
    1 - Math.pow(2, -9 * badgeEntry) * Math.cos(badgeEntry * Math.PI * 4.5);
  const badgeScale = 0.92 + 0.08 * badgeProgress;
  const flashOpacity =
    0.055 *
    interpolate(elapsed, [0, 0.06], [0, 1], clamp) *
    interpolate(elapsed, [0.16, 0.48], [1, 0], clamp);

  return (
    <AbsoluteFill
      style={{
        background:
          "linear-gradient(135deg, rgb(28,33,43) 0%, rgb(9,12,17) 100%)",
        color: "white",
        fontFamily:
          "-apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Helvetica Neue', sans-serif",
        overflow: "hidden",
      }}
    >
      <div
        style={{
          backgroundColor: "rgba(0,0,0,0.24)",
          height: 42,
          left: 0,
          position: "absolute",
          right: 0,
          top: 0,
        }}
      />
      {[
        "rgba(255,95,87,0.75)",
        "rgba(255,189,46,0.75)",
        "rgba(40,201,64,0.75)",
      ].map((color, index) => (
        <div
          key={color}
          style={{
            backgroundColor: color,
            borderRadius: "50%",
            height: 10,
            left: 18 + index * 18,
            position: "absolute",
            top: 16,
            width: 10,
          }}
        />
      ))}
      <div
        style={{
          backgroundColor: "rgba(255,255,255,0.08)",
          borderRadius: 5,
          height: 18,
          left: "50%",
          position: "absolute",
          top: 12,
          transform: "translateX(-50%)",
          width: 320,
        }}
      />
      <div
        style={{
          backgroundColor: "rgba(0,0,0,0.18)",
          bottom: 0,
          left: 0,
          position: "absolute",
          top: 42,
          width: 220,
        }}
      >
        {Array.from({ length: 8 }, (_, index) => (
          <div
            key={index}
            style={{
              backgroundColor:
                index === 2
                  ? "rgba(255,255,255,0.18)"
                  : "rgba(255,255,255,0.08)",
              borderRadius: 4,
              height: 11,
              left: 24,
              position: "absolute",
              top: 24 + index * 28,
              width: index === 2 ? 154 : 126,
            }}
          />
        ))}
      </div>
      <div
        style={{
          backgroundColor: "rgba(255,255,255,0.14)",
          borderRadius: 8,
          height: 24,
          left: 262,
          position: "absolute",
          top: 84,
          width: 420,
        }}
      />
      <div
        style={{
          backgroundColor: "rgba(255,255,255,0.07)",
          borderRadius: 6,
          height: 13,
          left: 262,
          position: "absolute",
          right: 42,
          top: 126,
        }}
      />
      <div
        style={{
          backgroundColor: "rgba(255,255,255,0.07)",
          borderRadius: 6,
          height: 13,
          left: 262,
          position: "absolute",
          top: 157,
          width: 680,
        }}
      />
      <div
        style={{
          backgroundColor: "#000",
          height: 32,
          left: "50%",
          position: "absolute",
          top: 0,
          transform: "translateX(-50%)",
          width: 185,
        }}
      />
      <AbsoluteFill
        style={{ backgroundColor: `rgba(79, 199, 125, ${flashOpacity})` }}
      />

      {screenConfettiPieces.map((piece, index) => {
        const time = Math.max(0, elapsed - piece.delay);
        const xVelocity = piece.fan * SCREEN_WIDTH * piece.horizontalVelocity;
        const horizontalTravel =
          (xVelocity * (1 - Math.exp(-piece.drag * time))) / piece.drag;
        const wobble =
          piece.wobble * Math.sin(piece.phase + piece.frequency * time);
        const x = SCREEN_WIDTH / 2 + horizontalTravel + wobble;
        const verticalVelocity = SCREEN_HEIGHT * piece.verticalVelocity;
        const gravity = SCREEN_HEIGHT * piece.gravity;
        const y = 28 + verticalVelocity * time + 0.5 * gravity * time * time;
        const opacity =
          interpolate(time, [0, 0.05], [0, 1], clamp) *
          interpolate(time, [1.4, 2.16], [1, 0], clamp);
        const rotation = piece.initialRotation + piece.spin * time;

        return (
          <div
            key={index}
            style={{
              backgroundColor:
                screenPalette[piece.colorIndex % screenPalette.length],
              borderRadius: 1.5,
              height: piece.height,
              left: 0,
              opacity,
              position: "absolute",
              top: 0,
              transform: `translate(${x - piece.width / 2}px, ${y - piece.height / 2}px) rotate(${rotation}rad)`,
              transformOrigin: "center",
              width: piece.width,
            }}
          />
        );
      })}

      <AbsoluteFill
        style={{
          border: `3px solid rgba(79, 199, 125, ${0.32 * badgeOpacity})`,
          borderRadius: 20,
          boxSizing: "border-box",
          inset: 10,
        }}
      />

      <div
        style={{
          alignItems: "center",
          backgroundColor: "rgba(0,0,0,0.88)",
          border: "1px solid rgba(255,255,255,0.10)",
          borderRadius: 20,
          boxShadow: "0 12px 28px rgba(0,0,0,0.36)",
          display: "flex",
          gap: 13,
          height: 82,
          left: "50%",
          opacity: badgeOpacity,
          padding: "0 18px",
          position: "absolute",
          top: "42%",
          transform: `translate(-50%, -50%) scale(${badgeScale})`,
        }}
      >
        <div
          style={{
            alignItems: "center",
            backgroundColor: GREEN,
            borderRadius: "50%",
            color: "rgba(0,0,0,0.88)",
            display: "flex",
            fontSize: 19,
            fontWeight: 900,
            height: 38,
            justifyContent: "center",
            width: 38,
          }}
        >
          <svg aria-hidden="true" height="20" viewBox="0 0 20 20" width="20">
            <path
              d="M3.8 10.4 8 14.5 16.2 5.7"
              fill="none"
              stroke="rgba(0,0,0,0.88)"
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth="2.8"
            />
          </svg>
        </div>
        <div
          style={{
            alignItems: "flex-start",
            display: "flex",
            flexDirection: "column",
            fontFamily:
              "ui-rounded, 'SF Pro Rounded', -apple-system, BlinkMacSystemFont, sans-serif",
            gap: 2,
            width: 270,
          }}
        >
          <span style={{ fontSize: 18, fontWeight: 650 }}>Task finished</span>
          <span
            style={{
              color: "#8ce6ab",
              fontSize: 13,
              fontWeight: 650,
              overflow: "hidden",
              textOverflow: "ellipsis",
              whiteSpace: "nowrap",
              width: "100%",
            }}
          >
            Codex Notch
          </span>
          <span
            style={{
              color: "rgba(255,255,255,0.62)",
              fontSize: 12,
              fontWeight: 520,
            }}
          >
            4 tasks still working
          </span>
        </div>
      </div>
    </AbsoluteFill>
  );
};

export const CelebrationCompositions: React.FC = () => {
  return (
    <>
      <Composition
        id="CompletionQuiet"
        component={Celebration}
        durationInFrames={72}
        fps={FPS}
        width={WIDTH}
        height={HEIGHT}
        defaultProps={{ durationInFrames: 72, variant: "quiet" }}
      />
      <Composition
        id="CompletionSpark"
        component={Celebration}
        durationInFrames={108}
        fps={FPS}
        width={WIDTH}
        height={HEIGHT}
        defaultProps={{ durationInFrames: 108, variant: "spark" }}
      />
      <Composition
        id="CompletionConfetti"
        component={Celebration}
        durationInFrames={108}
        fps={FPS}
        width={WIDTH}
        height={HEIGHT}
        defaultProps={{ durationInFrames: 108, variant: "confetti" }}
      />
      <Composition
        id="CompletionAllDone"
        component={Celebration}
        durationInFrames={96}
        fps={FPS}
        width={WIDTH}
        height={HEIGHT}
        defaultProps={{ durationInFrames: 96, variant: "allDone" }}
      />
      <Composition
        id="CompletionScreenConfetti"
        component={ScreenCompletionConfetti}
        durationInFrames={SCREEN_DURATION}
        fps={FPS}
        width={SCREEN_WIDTH}
        height={SCREEN_HEIGHT}
      />
    </>
  );
};
