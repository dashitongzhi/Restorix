import {Composition} from "remotion";
import {RestorixPromo} from "./Promo";

export const MyComposition: React.FC = () => {
  return (
    <Composition
      id="RestorixPromo"
      component={RestorixPromo}
      durationInFrames={2880}
      fps={30}
      width={1920}
      height={1080}
      defaultProps={{
        title: "Restorix",
        tagline: "让 Docker volume 的备份状态有证据、可解释、可行动。",
      }}
    />
  );
};
