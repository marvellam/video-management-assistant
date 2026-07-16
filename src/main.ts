import { invoke } from "@tauri-apps/api/core";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { open } from "@tauri-apps/plugin-dialog";

interface FolderNode {
  name: string;
  children?: FolderNode[];
}

interface ProjectTemplate {
  templateId: string;
  templateVersion: number;
  templateName: string;
  rootPattern: string;
  folders: FolderNode[];
  namingRules: unknown[];
  isOfficial: boolean;
}

interface TemplateLibrary {
  selectedTemplateId: string;
  templates: ProjectTemplate[];
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
  templateSelect: document.querySelector<HTMLSelectElement>("#templateSelect")!,
  editTemplateButton: document.querySelector<HTMLButtonElement>("#editTemplateButton")!,
  templateModal: document.querySelector<HTMLDivElement>("#templateModal")!,
  templateBackdrop: document.querySelector<HTMLDivElement>("#templateBackdrop")!,
  closeTemplateButton: document.querySelector<HTMLButtonElement>("#closeTemplateButton")!,
  duplicateOfficialButton: document.querySelector<HTMLButtonElement>("#duplicateOfficialButton")!,
  newBlankTemplateButton: document.querySelector<HTMLButtonElement>("#newBlankTemplateButton")!,
  templateName: document.querySelector<HTMLInputElement>("#templateName")!,
  templateTypeBadge: document.querySelector<HTMLSpanElement>("#templateTypeBadge")!,
  templateTreeEditor: document.querySelector<HTMLDivElement>("#templateTreeEditor")!,
  addRootFolderButton: document.querySelector<HTMLButtonElement>("#addRootFolderButton")!,
  deleteTemplateButton: document.querySelector<HTMLButtonElement>("#deleteTemplateButton")!,
  saveTemplateButton: document.querySelector<HTMLButtonElement>("#saveTemplateButton")!,
  templateEditorStatus: document.querySelector<HTMLParagraphElement>("#templateEditorStatus")!,
};

const appWindow = getCurrentWindow();
let library: TemplateLibrary;
let template: ProjectTemplate;
let draftTemplate: ProjectTemplate | null = null;
let editorDirty = false;
let discardArmed = false;
let deleteArmed = false;

if (import.meta.env.VITE_TARGET_PLATFORM === "macos") {
  document.documentElement.classList.add("platform-macos");
}

function cloneValue<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

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

function setEditorStatus(
  text: string,
  type: "neutral" | "success" | "error" = "neutral",
): void {
  elements.templateEditorStatus.textContent = text;
  elements.templateEditorStatus.className = type === "neutral" ? "" : type;
}

async function runWindowAction(action: () => Promise<void>, label: string): Promise<void> {
  try {
    await action();
  } catch (error) {
    setStatus(`${label}失败：${String(error)}`, "error");
  }
}

function renderPreview(): void {
  if (!template) return;
  const date = elements.projectDate.value.trim() || "YYYYMMDD";
  const name = elements.projectName.value.trim() || "项目名称";
  elements.previewTitle.textContent = template.rootPattern
    .replaceAll("{date}", date)
    .replaceAll("{project_name}", name);
  elements.treePreview.textContent = buildTreeLines(template.folders).join("\n");
}

function updateValidation(): void {
  elements.nameError.textContent = elements.projectName.value
    ? validateName(elements.projectName.value)
    : "";
  elements.dateError.textContent = validateDate(elements.projectDate.value);
}

function applyTemplateLibrary(nextLibrary: TemplateLibrary): void {
  library = nextLibrary;
  const selected =
    library.templates.find((item) => item.templateId === library.selectedTemplateId) ??
    library.templates[0];
  template = selected;
  library.selectedTemplateId = selected.templateId;

  elements.templateSelect.replaceChildren();
  for (const item of library.templates) {
    const option = document.createElement("option");
    option.value = item.templateId;
    option.textContent = `${item.isOfficial ? "官方" : "我的"} · ${item.templateName}`;
    option.selected = item.templateId === selected.templateId;
    elements.templateSelect.append(option);
  }
  renderPreview();
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

async function changeTemplate(): Promise<void> {
  const previousId = template.templateId;
  elements.templateSelect.disabled = true;
  try {
    template = await invoke<ProjectTemplate>("select_template", {
      templateId: elements.templateSelect.value,
    });
    library.selectedTemplateId = template.templateId;
    renderPreview();
    setStatus(`已选择“${template.templateName}”`);
  } catch (error) {
    elements.templateSelect.value = previousId;
    setStatus(String(error), "error");
  } finally {
    elements.templateSelect.disabled = false;
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
        templateId: template.templateId,
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

function getNodeContainer(parentPath: number[]): FolderNode[] {
  if (!draftTemplate) return [];
  let nodes = draftTemplate.folders;
  for (const index of parentPath) {
    nodes[index].children ??= [];
    nodes = nodes[index].children;
  }
  return nodes;
}

function markEditorDirty(): void {
  editorDirty = true;
  discardArmed = false;
  deleteArmed = false;
  elements.deleteTemplateButton.textContent = "删除模板";
  elements.saveTemplateButton.disabled = false;
  setEditorStatus("尚未保存");
}

function focusEditorPath(path: number[]): void {
  requestAnimationFrame(() => {
    const input = elements.templateTreeEditor.querySelector<HTMLInputElement>(
      `[data-path="${path.join(".")}"] input`,
    );
    input?.focus();
    input?.select();
  });
}

function createRowAction(label: string, title: string, onClick: () => void): HTMLButtonElement {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "tree-row-action";
  button.textContent = label;
  button.title = title;
  button.setAttribute("aria-label", title);
  button.addEventListener("click", onClick);
  return button;
}

function renderEditorNodes(nodes: FolderNode[], parentPath: number[], depth: number): void {
  nodes.forEach((node, index) => {
    const path = [...parentPath, index];
    const row = document.createElement("div");
    row.className = "template-tree-row";
    row.dataset.path = path.join(".");
    row.style.setProperty("--tree-depth", String(depth));

    if (!draftTemplate?.isOfficial) {
      const orderMark = document.createElement("span");
      orderMark.className = "tree-order-mark";
      orderMark.textContent = "·";
      row.append(orderMark);
    } else {
      const branch = document.createElement("span");
      branch.className = "tree-readonly-mark";
      branch.textContent = "└";
      row.append(branch);
    }

    if (draftTemplate?.isOfficial) {
      const name = document.createElement("span");
      name.className = "tree-readonly-name";
      name.textContent = node.name;
      row.append(name);
    } else {
      const input = document.createElement("input");
      input.type = "text";
      input.value = node.name;
      input.maxLength = 80;
      input.setAttribute("aria-label", `第 ${index + 1} 个文件夹名称`);
      input.addEventListener("input", () => {
        node.name = input.value;
        markEditorDirty();
      });
      row.append(input);

      const actions = document.createElement("div");
      actions.className = "tree-row-actions";
      const moveUpButton = createRowAction("上移", "向上移动", () => {
        if (index === 0) return;
        const siblings = getNodeContainer(parentPath);
        [siblings[index - 1], siblings[index]] = [siblings[index], siblings[index - 1]];
        markEditorDirty();
        renderTemplateEditor();
        focusEditorPath([...parentPath, index - 1]);
      });
      moveUpButton.disabled = index === 0;
      const moveDownButton = createRowAction("下移", "向下移动", () => {
        const siblings = getNodeContainer(parentPath);
        if (index >= siblings.length - 1) return;
        [siblings[index], siblings[index + 1]] = [siblings[index + 1], siblings[index]];
        markEditorDirty();
        renderTemplateEditor();
        focusEditorPath([...parentPath, index + 1]);
      });
      moveDownButton.disabled = index === nodes.length - 1;
      actions.append(
        moveUpButton,
        moveDownButton,
        createRowAction("同级", "在下方添加同级目录", () => {
          const siblings = getNodeContainer(parentPath);
          siblings.splice(index + 1, 0, { name: "新建文件夹", children: [] });
          markEditorDirty();
          renderTemplateEditor();
          focusEditorPath([...parentPath, index + 1]);
        }),
        createRowAction("子目录", "添加子目录", () => {
          node.children ??= [];
          node.children.push({ name: "新建文件夹", children: [] });
          const childPath = [...path, node.children.length - 1];
          markEditorDirty();
          renderTemplateEditor();
          focusEditorPath(childPath);
        }),
        createRowAction("删除", "删除这个目录及其子目录", () => {
          const siblings = getNodeContainer(parentPath);
          siblings.splice(index, 1);
          markEditorDirty();
          renderTemplateEditor();
        }),
      );
      row.append(actions);
    }

    elements.templateTreeEditor.append(row);
    if (node.children?.length) {
      renderEditorNodes(node.children, path, depth + 1);
    }
  });
}

function renderTemplateEditor(): void {
  if (!draftTemplate) return;
  const readOnly = draftTemplate.isOfficial;
  elements.templateName.value = draftTemplate.templateName;
  elements.templateName.disabled = readOnly;
  elements.templateTypeBadge.textContent = readOnly ? "官方模板" : "我的模板";
  elements.templateTypeBadge.classList.toggle("custom", !readOnly);
  elements.addRootFolderButton.hidden = readOnly;
  elements.deleteTemplateButton.hidden = readOnly || !draftTemplate.templateId;
  elements.saveTemplateButton.hidden = readOnly;
  elements.saveTemplateButton.disabled = !editorDirty;
  elements.templateTreeEditor.classList.toggle("read-only", readOnly);
  elements.templateTreeEditor.replaceChildren();

  if (draftTemplate.folders.length === 0) {
    const empty = document.createElement("div");
    empty.className = "template-empty-state";
    empty.textContent = "还没有目录，点击下方按钮添加第一个一级目录。";
    elements.templateTreeEditor.append(empty);
  } else {
    renderEditorNodes(draftTemplate.folders, [], 0);
  }

  if (readOnly) {
    setEditorStatus("官方模板保持只读。可以基于它创建自己的模板。");
  } else if (!editorDirty) {
    setEditorStatus("修改会保存在当前电脑。使用上移、下移调整同级顺序。");
  }
}

function uniqueTemplateName(base: string): string {
  const names = new Set(library.templates.map((item) => item.templateName.toLowerCase()));
  if (!names.has(base.toLowerCase())) return base;
  let index = 2;
  while (names.has(`${base} ${index}`.toLowerCase())) index += 1;
  return `${base} ${index}`;
}

function startCustomTemplate(source: "official" | "blank"): void {
  const official = library.templates.find((item) => item.isOfficial)!;
  draftTemplate =
    source === "official"
      ? {
          ...cloneValue(official),
          templateId: "",
          templateVersion: 1,
          templateName: uniqueTemplateName(`${official.templateName} · 自定义`),
          namingRules: [],
          isOfficial: false,
        }
      : {
          templateId: "",
          templateVersion: 1,
          templateName: uniqueTemplateName("我的目录模板"),
          rootPattern: "{date}_{project_name}",
          folders: [{ name: "新建文件夹", children: [] }],
          namingRules: [],
          isOfficial: false,
        };
  editorDirty = true;
  discardArmed = false;
  deleteArmed = false;
  renderTemplateEditor();
  setEditorStatus(source === "official" ? "已复制官方结构，修改后保存即可。" : "已创建空白模板。", "success");
  elements.templateName.focus();
  elements.templateName.select();
}

function openTemplateEditor(): void {
  draftTemplate = cloneValue(template);
  editorDirty = false;
  discardArmed = false;
  deleteArmed = false;
  elements.deleteTemplateButton.textContent = "删除模板";
  elements.templateModal.hidden = false;
  document.body.classList.add("modal-open");
  renderTemplateEditor();
  elements.closeTemplateButton.focus();
}

function closeTemplateEditor(force = false): void {
  if (!force && editorDirty && !discardArmed) {
    discardArmed = true;
    setEditorStatus("有未保存修改，再次点击关闭将放弃。", "error");
    return;
  }
  elements.templateModal.hidden = true;
  document.body.classList.remove("modal-open");
  draftTemplate = null;
  editorDirty = false;
  discardArmed = false;
  deleteArmed = false;
  elements.editTemplateButton.focus();
}

async function saveDraftTemplate(): Promise<void> {
  if (!draftTemplate || draftTemplate.isOfficial) return;
  draftTemplate.templateName = elements.templateName.value;
  elements.saveTemplateButton.disabled = true;
  elements.saveTemplateButton.textContent = "保存中…";
  try {
    const nextLibrary = await invoke<TemplateLibrary>("save_template", {
      template: draftTemplate,
    });
    applyTemplateLibrary(nextLibrary);
    closeTemplateEditor(true);
    setStatus(`模板“${template.templateName}”已保存并选中`, "success");
  } catch (error) {
    setEditorStatus(String(error), "error");
    elements.saveTemplateButton.disabled = false;
  } finally {
    elements.saveTemplateButton.textContent = "保存模板";
  }
}

async function deleteDraftTemplate(): Promise<void> {
  if (!draftTemplate || draftTemplate.isOfficial || !draftTemplate.templateId) return;
  if (!deleteArmed) {
    deleteArmed = true;
    elements.deleteTemplateButton.textContent = "确认删除";
    setEditorStatus("再次点击“确认删除”将永久删除这个本机模板。", "error");
    return;
  }
  elements.deleteTemplateButton.disabled = true;
  try {
    const deletedName = draftTemplate.templateName;
    const nextLibrary = await invoke<TemplateLibrary>("delete_template", {
      templateId: draftTemplate.templateId,
    });
    applyTemplateLibrary(nextLibrary);
    closeTemplateEditor(true);
    setStatus(`已删除模板“${deletedName}”`);
  } catch (error) {
    setEditorStatus(String(error), "error");
  } finally {
    elements.deleteTemplateButton.disabled = false;
  }
}

async function initialize(): Promise<void> {
  elements.projectDate.value = todayStamp();
  applyTemplateLibrary(await invoke<TemplateLibrary>("get_template_library"));
  updateValidation();

  elements.projectName.addEventListener("input", () => {
    renderPreview();
    updateValidation();
  });
  elements.projectDate.addEventListener("input", () => {
    elements.projectDate.value = elements.projectDate.value.replace(/\D/g, "").slice(0, 8);
    renderPreview();
    updateValidation();
  });
  elements.chooseDirectory.addEventListener("click", () => void chooseTargetRoot());
  elements.templateSelect.addEventListener("change", () => void changeTemplate());
  elements.editTemplateButton.addEventListener("click", openTemplateEditor);
  elements.closeTemplateButton.addEventListener("click", () => closeTemplateEditor());
  elements.templateBackdrop.addEventListener("click", () => closeTemplateEditor());
  elements.duplicateOfficialButton.addEventListener("click", () => startCustomTemplate("official"));
  elements.newBlankTemplateButton.addEventListener("click", () => startCustomTemplate("blank"));
  elements.templateName.addEventListener("input", () => {
    if (!draftTemplate || draftTemplate.isOfficial) return;
    draftTemplate.templateName = elements.templateName.value;
    markEditorDirty();
  });
  elements.addRootFolderButton.addEventListener("click", () => {
    if (!draftTemplate || draftTemplate.isOfficial) return;
    draftTemplate.folders.push({ name: "新建文件夹", children: [] });
    const path = [draftTemplate.folders.length - 1];
    markEditorDirty();
    renderTemplateEditor();
    focusEditorPath(path);
  });
  elements.saveTemplateButton.addEventListener("click", () => void saveDraftTemplate());
  elements.deleteTemplateButton.addEventListener("click", () => void deleteDraftTemplate());
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
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape" && !elements.templateModal.hidden) closeTemplateEditor();
  });
  elements.projectName.focus();
}

initialize().catch((error) => {
  setStatus(`应用启动失败：${String(error)}`, "error");
  elements.generateButton.disabled = true;
});
