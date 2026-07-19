# RestorixPromo Remotion 工程

## Commands

```bash
npm install
npm run captions
npm run lint
npm run dev
npm run still
npm run render
```

Composition ID：`RestorixPromo`

项目时间线、字幕、音频与截图素材均保持可编辑。画面使用 Remotion 的 `Sequence`、`interpolate()` 与普通 React/CSS 编排，没有 CSS transition 或 CSS animation。

旁白参数：

```bash
uvx edge-tts \
  --file scripts/narration-zh.txt \
  --voice zh-CN-XiaoxiaoNeural \
  --rate=+4% \
  --pitch=-2Hz \
  --write-media public/audio/narration.mp3 \
  --write-subtitles public/captions/narration.vtt
```

随后运行 `npm run captions`，把 VTT 转为 `Caption[]` JSON。
