# Restorix 宣传演示视频

该目录包含可编辑的 Remotion 工程、真实 Restorix macOS 截图、两张生成式辅助视觉素材、中文神经语音旁白和最终 1080p 成片。

## 交付物

- 成片：`output/restorix-promo-zh-1080p.mp4`
- 可编辑工程：`project/`
- 最终镜头抽检图：`review/final-contact-sheet.png`

## 成片规格

- 1920 × 1080
- 30 fps
- 约 96 秒
- H.264 视频 + AAC 立体声音轨
- Remotion composition：`RestorixPromo`

## 旁白

旁白由 `edge-tts` 调用 Microsoft Edge 在线神经语音服务生成：

- Voice：`zh-CN-XiaoxiaoNeural`
- Rate：`+4%`
- Pitch：`-2Hz`

完整旁白位于 `project/scripts/narration-zh.txt`，VTT 与 Remotion Caption JSON 位于 `project/public/captions/`。

## 素材真实性

`project/public/screenshots/` 内的界面均来自当前仓库刚刚构建运行的真实 `Restorix.app`。首页素材只保留健康状态与建议区域，已裁除包含本机路径的诊断文本。

生成图片仅承担开场氛围与抽象比对转场，不承担产品界面或功能证明。完整提示词位于 `project/public/generated/PROMPTS.md`。

## 编辑与渲染

```bash
cd project
npm install
npm run lint
npm run dev
npm run render
```

当前渲染脚本复用本机 `/Applications/Google Chrome.app`，避免首次下载 Headless Chrome。其他机器可调整 `package.json` 中的 `--browser-executable`，或删除该参数让 Remotion 自动下载渲染器。
