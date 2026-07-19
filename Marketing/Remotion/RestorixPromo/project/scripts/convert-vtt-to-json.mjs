import {readFile, writeFile} from "node:fs/promises";

const source = new URL("../public/captions/narration.vtt", import.meta.url);
const destination = new URL("../public/captions/narration.json", import.meta.url);

const parseTime = (value) => {
  const [hours, minutes, seconds] = value.replace(",", ".").split(":");
  return Math.round(
    (Number(hours) * 3600 + Number(minutes) * 60 + Number(seconds)) * 1000,
  );
};

const blocks = (await readFile(source, "utf8"))
  .replace(/^WEBVTT\s*/u, "")
  .trim()
  .split(/\n\s*\n/u);

const captions = blocks.map((block) => {
  const lines = block.trim().split("\n");
  const timingIndex = lines.findIndex((line) => line.includes(" --> "));
  const [start, end] = lines[timingIndex].split(" --> ");
  return {
    text: lines.slice(timingIndex + 1).join(" ").trim(),
    startMs: parseTime(start),
    endMs: parseTime(end),
    timestampMs: null,
    confidence: null,
  };
});

await writeFile(destination, `${JSON.stringify(captions, null, 2)}\n`);
console.log(`Wrote ${captions.length} captions to ${destination.pathname}`);
