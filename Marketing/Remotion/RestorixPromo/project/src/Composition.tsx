import {Composition} from "remotion";
import {RestorixPromo} from "./Promo";

export const MyComposition: React.FC = () => {
  return (
    <Composition
      id="RestorixPromo"
      component={RestorixPromo}
      durationInFrames={2475}
      fps={30}
      width={1920}
      height={1080}
      defaultProps={{
        title: "Restorix",
        tagline: "检查 Docker volume 的备份覆盖情况",
      }}
    />
  );
};
