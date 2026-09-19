import fs from "node:fs/promises";
import path from "node:path";
import { FileBlob, SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const workspace = "C:/Users/anhnt3/projects/hrm";
const sourcePath = path.join(workspace, "sap", "zmsg_iam07_catalog.csv");
const outputDir = path.join(workspace, "outputs", "zmsg_iam07_message_class");
const outputPath = path.join(outputDir, "ZMSG_IAM07_Message_Class.xlsx");
const previewPath = path.join(outputDir, "ZMSG_IAM07_Message_Class_preview.png");

const csvText = await fs.readFile(sourcePath, "utf8");
const imported = await Workbook.fromCSV(csvText, { sheetName: "Catalog" });
const importedSheet = imported.worksheets.getItem("Catalog");
const importedValues = importedSheet.getUsedRange(true).values;

if (!Array.isArray(importedValues) || importedValues.length < 2) {
  throw new Error("The source catalog is empty or invalid.");
}

const headers = importedValues[0].map((value) => String(value ?? "").trim());
const msgNoIndex = headers.indexOf("MSGNO");
const textIndex = headers.indexOf("TEXT");
if (msgNoIndex < 0 || textIndex < 0) {
  throw new Error("Required MSGNO/TEXT columns were not found.");
}

const rows = importedValues.slice(1).map((row) => [
  Number.parseInt(String(row[msgNoIndex] ?? ""), 10),
  String(row[textIndex] ?? ""),
]);

if (rows.length !== 101) {
  throw new Error(`Expected 101 messages, found ${rows.length}.`);
}

const numbers = rows.map((row) => row[0]);
if (numbers.some((number) => !Number.isInteger(number) || number < 0 || number > 999)) {
  throw new Error("Invalid message number was found.");
}
if (new Set(numbers).size !== rows.length) {
  throw new Error("Duplicate message numbers were found.");
}

const tooLong = rows.filter((row) => row[1].length > 73);
if (tooLong.length > 0) {
  throw new Error(`Short Text exceeds 73 characters: ${tooLong.map((row) => String(row[0]).padStart(3, "0")).join(", ")}`);
}

const workbook = Workbook.create();
const sheet = workbook.worksheets.add("Messages");
sheet.showGridLines = false;
sheet.freezePanes.freezeRows(1);

sheet.getRange(`A1:B${rows.length + 1}`).values = [
  ["Number", "Short Text"],
  ...rows,
];

const header = sheet.getRange("A1:B1");
header.format = {
  fill: "#E6E8EB",
  font: { bold: true, color: "#1F2937" },
  verticalAlignment: "center",
  borders: {
    bottom: { style: "medium", color: "#9CA3AF" },
  },
};
header.format.rowHeight = 24;

const body = sheet.getRange(`A2:B${rows.length + 1}`);
body.format = {
  fill: "#FFFFFF",
  font: { color: "#1F2937" },
  verticalAlignment: "center",
  borders: {
    insideHorizontal: { style: "thin", color: "#E5E7EB" },
  },
};
body.format.rowHeight = 20;

sheet.getRange(`A2:A${rows.length + 1}`).format.numberFormat = "000";
sheet.getRange(`A1:A${rows.length + 1}`).format.horizontalAlignment = "left";
sheet.getRange(`B1:B${rows.length + 1}`).format.horizontalAlignment = "left";
sheet.getRange(`A1:A${rows.length + 1}`).format.columnWidth = 12;
sheet.getRange(`B1:B${rows.length + 1}`).format.columnWidth = 72;

await fs.mkdir(outputDir, { recursive: true });
const exported = await SpreadsheetFile.exportXlsx(workbook);
await exported.save(outputPath);

const outputBlob = await FileBlob.load(outputPath);
const verifiedWorkbook = await SpreadsheetFile.importXlsx(outputBlob);
const verifiedSheet = verifiedWorkbook.worksheets.getItem("Messages");
const verifiedValues = verifiedSheet.getUsedRange(true).values;

const preview = await verifiedWorkbook.render({
  sheetName: "Messages",
  range: `A1:B${rows.length + 1}`,
  scale: 0.8,
  format: "png",
});
await fs.writeFile(previewPath, new Uint8Array(await preview.arrayBuffer()));

console.log(JSON.stringify({
  outputPath,
  previewPath,
  rowCount: rows.length,
  first: [String(rows[0][0]).padStart(3, "0"), rows[0][1]],
  last: [String(rows.at(-1)[0]).padStart(3, "0"), rows.at(-1)[1]],
  maxTextLength: Math.max(...rows.map((row) => row[1].length)),
  verifiedRows: verifiedValues.length - 1,
  verifiedLastText: verifiedValues.at(-1)?.[1],
}, null, 2));
