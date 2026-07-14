import { invoke } from "@tauri-apps/api/core";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { open } from "@tauri-apps/plugin-dialog";

interface FolderNode {
  name: string;
  children?: FolderNode[];
}

interface ProjectTemplate {
  templateVersion: number;
  templateName: string;
  rootPattern: string;
  folders: FolderNode[];
}

interface CreateProjectResult {
  projectPath: string;
  createdCount: number;
  existingCount: number;
}

const elements = {
  titleBar: document.querySelector<HTMLElement>("#titleBar")!,
  minimizeButton: document.querySelector<HTMLButtonElement>("#minimizeButton")!,
  closeButton: document.querySelector<HTMLButtonElement>("#closeButton")!,
  form: document.querySelector<HTMLFormElement>("#projectForm")!,
  projectName: document.querySelector<HTMLInputElement>("#projectName")!,
  projectDate: document.querySelector<HTMLInputElement>("#projectDate")!,
  targetRoot: document.querySelector<HTMLInputElement>("#targetRoot")!,
  chooseDirectory: document.querySelector<HTMLButtonElement>("#chooseDirectory")!,
  openAfter: document.querySelector<HTMLInputElement>("#openAfter")!,
  nameError: document.querySelector<HTMLParagraphElement>("#nameError")!,
  dateError: document.querySelector<HTMLParagraphElement>("#dateError")!,
  generateButton: document.querySelector<HTMLButtonElement>("#generateButton")!,
  statusText: document.querySelector<HTMLParagraphElement>("#statusText")!,
  previewTitle: document.querySelector<HTMLHeadingElement>("#previewTitle")!,
  treePreview: document.querySelector<HTMLPreElement>("#treePreview")!,
};

const appWindow = getCurrentWindow();
let template: ProjectTemplate;

function todayStamp(): string {
  const today = new Date();
  return [
    today.getFullYear(),
    String(today.getMonth() + 1).padStart(2, "0"),
    String(today.getDate()).padStart(2, "0"),
  ].join("");
}

function validateDate(value: string): string {
  if (!/^\d{8}$/.test(value)) {
    return "请输入有效的 8 位日期。";
  }
  const year = Number(value.slice(0, 4));
  const month = Number(value.slice(4, 6));
  const day = Number(value.slice(6, 8));
  const parsed = new Date(Date.UTC(year, month - 1, day));
  return parsed.getUTCFullYear() === year &&
    parsed.getUTCMonth() + 1 === month &&
    parsed.getUTCDate() === day
    ? ""
    : "请输入有效的 8 位日期。";
}

function validateName(value: string): string {
  const name = value.trim();
  if (!name) return "项目名称不能为空。";
  if (name.endsWith(".") || name.endsWith(" ")) return "不能以句点或空格结尾。";
  const invalid = name.match(/[<>:"/\\|?*\u0000-\u001f]/)?.[0];
  if (invalid) return `包含不允许的字符：${invalid}`;
  if (/^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$/i.test(name)) {
    return "这是系统保留名称，请更换。";
  }
  return "";
}

function buildTreeLines(nodes: FolderNode[], prefix = ""): string[] {
  const lines: string[] = [];
  nodes.forEach((node, index) => {
    const last = index === nodes.length - 1;
    lines.push(`${prefix}${last ? "└─" : "├─"} ${node.name}`);
    if (node.children?.length) {
      lines.push(...buildTreeLines(node.children, `${prefix}${last ? "   " : "│  "}`));
    }
  });
  return lines;
}

function setStatus(text: string, type: "neutral" | "success" | "error" = "neutral"): void {
  elements.statusText.textContent = text;
  elements.statusText.className = `status-text${type === "neutral" ? "" : ` ${type}`}`;
}

async function runWindowAction(action: () => Promise<void>, label: string): Promise<void> {
  try {
    await action();
  } catch (error) {
    setStatus(`${label}失败：${String(error)}`, "error");
  }
}

function updatePreview(): void {
  if (!template) return;
  const date = elements.projectDate.value.trim() || "YYYYMMDD";
  const name = elements.projectName.value.trim() || "项目名称";
  elements.previewTitle.textContent = template.rootPattern
    .replaceAll("{date}", date)
    .replaceAll("{project_name}", name);
}

function updateValidation(): void {
  elements.nameError.textContent = elements.projectName.value
    ? validateName(elements.projectName.value)
    : "";
  elements.dateError.textContent = validateDate(elements.projectDate.value);
}

async function chooseTargetRoot(): Promise<void> {
  const selected = await open({
    directory: true,
    multiple: false,
    title: "请选择项目目录的保存位置",
  });
  if (typeof selected === "string") {
    elements.targetRoot.value = selected;
    elements.targetRoot.title = selected;
    setStatus("已选择保存位置");
  }
}

async function generateProject(event: SubmitEvent): Promise<void> {
  event.preventDefault();
  const nameError = validateName(elements.projectName.value);
  const dateError = validateDate(elements.projectDate.value);
  elements.nameError.textContent = nameError;
  elements.dateError.textContent = dateError;

  if (nameError || dateError) {
    setStatus(nameError || dateError, "error");
    return;
  }
  if (!elements.targetRoot.value) {
    setStatus("请先选择保存位置。", "error");
    return;
  }

  elements.generateButton.disabled = true;
  elements.generateButton.textContent = "正在生成…";
  setStatus("正在检查并补建目录…");

  try {
    const result = await invoke<CreateProjectResult>("create_project", {
      request: {
        targetRoot: elements.targetRoot.value,
        projectName: elements.projectName.value,
        projectDate: elements.projectDate.value,
        openAfter: elements.openAfter.checked,
      },
    });

    elements.generateButton.textContent = "已完成";
    setStatus(
      `新建 ${result.createdCount} 个 · 已有 ${result.existingCount} 个\n${result.projectPath}`,
      "success",
    );
  } catch (error) {
    elements.generateButton.textContent = "重新生成";
    setStatus(String(error), "error");
  } finally {
    elements.generateButton.disabled = false;
  }
}

async function initialize(): Promise<void> {
  elements.projectDate.value = todayStamp();
  template = await invoke<ProjectTemplate>("get_template");
  elements.treePreview.textContent = buildTreeLines(template.folders).join("\n");
  updatePreview();

  elements.projectName.addEventListener("input", () => {
    updatePreview();
    updateValidation();
  });
  elements.projectDate.addEventListener("input", () => {
    elements.projectDate.value = elements.projectDate.value.replace(/\D/g, "").slice(0, 8);
    updatePreview();
    updateValidation();
  });
  elements.chooseDirectory.addEventListener("click", () => void chooseTargetRoot());
  elements.form.addEventListener("submit", (event) => void generateProject(event));
  elements.minimizeButton.addEventListener("click", () =>
    void runWindowAction(() => appWindow.minimize(), "最小化窗口"),
  );
  elements.closeButton.addEventListener("click", () =>
    void runWindowAction(() => appWindow.close(), "关闭窗口"),
  );
  elements.titleBar.addEventListener("dblclick", (event) => {
    if ((event.target as HTMLElement).closest("button")) return;
    void runWindowAction(() => appWindow.toggleMaximize(), "切换窗口大小");
  });
  elements.projectName.focus();
}

initialize().catch((error) => {
  setStatus(`应用启动失败：${String(error)}`, "error");
  elements.generateButton.disabled = true;
});
