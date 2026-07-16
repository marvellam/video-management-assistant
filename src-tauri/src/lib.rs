use chrono::NaiveDate;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};
use tauri::Manager;
use tauri_plugin_opener::OpenerExt;

const TEMPLATE_JSON: &str = include_str!("../../template.json");
const OFFICIAL_TEMPLATE_ID: &str = "official-video-standard";
const TEMPLATE_STORE_FILE: &str = "templates.json";
const ROOT_PATTERN: &str = "{date}_{project_name}";

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct ProjectTemplate {
    #[serde(default, alias = "template_id")]
    template_id: String,
    #[serde(alias = "template_version")]
    template_version: u32,
    #[serde(alias = "template_name")]
    template_name: String,
    #[serde(alias = "root_pattern")]
    root_pattern: String,
    folders: Vec<FolderNode>,
    #[serde(default, alias = "naming_rules")]
    naming_rules: Vec<NamingRule>,
    #[serde(default, alias = "is_official")]
    is_official: bool,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
struct FolderNode {
    name: String,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    children: Vec<FolderNode>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct NamingRule {
    #[serde(alias = "applies_to")]
    applies_to: String,
    rule: String,
    #[serde(alias = "create_as_folder")]
    create_as_folder: bool,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct TemplateStore {
    selected_template_id: String,
    templates: Vec<ProjectTemplate>,
}

impl Default for TemplateStore {
    fn default() -> Self {
        Self {
            selected_template_id: OFFICIAL_TEMPLATE_ID.into(),
            templates: Vec::new(),
        }
    }
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct TemplateLibrary {
    selected_template_id: String,
    templates: Vec<ProjectTemplate>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct CreateProjectRequest {
    target_root: String,
    project_name: String,
    project_date: String,
    open_after: bool,
    template_id: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct CreateProjectResult {
    project_path: String,
    created_count: usize,
    existing_count: usize,
}

fn official_template() -> Result<ProjectTemplate, String> {
    let mut template: ProjectTemplate =
        serde_json::from_str(TEMPLATE_JSON).map_err(|error| format!("目录模板无效：{error}"))?;
    template.template_id = OFFICIAL_TEMPLATE_ID.into();
    template.is_official = true;
    Ok(template)
}

fn template_store_path(config_dir: &Path) -> PathBuf {
    config_dir.join(TEMPLATE_STORE_FILE)
}

fn load_template_store(config_dir: &Path) -> Result<TemplateStore, String> {
    let path = template_store_path(config_dir);
    if !path.exists() {
        return Ok(TemplateStore::default());
    }
    let contents = fs::read_to_string(&path)
        .map_err(|error| format!("无法读取模板库 {}：{error}", path.display()))?;
    serde_json::from_str(&contents)
        .map_err(|error| format!("模板库内容无效 {}：{error}", path.display()))
}

fn save_template_store(config_dir: &Path, store: &TemplateStore) -> Result<(), String> {
    fs::create_dir_all(config_dir)
        .map_err(|error| format!("无法创建模板存储目录 {}：{error}", config_dir.display()))?;
    let contents = serde_json::to_string_pretty(store)
        .map_err(|error| format!("无法整理模板库数据：{error}"))?;
    let path = template_store_path(config_dir);
    fs::write(&path, contents)
        .map_err(|error| format!("无法保存模板库 {}：{error}", path.display()))
}

fn app_config_dir(app: &tauri::AppHandle) -> Result<PathBuf, String> {
    app.path()
        .app_config_dir()
        .map_err(|error| format!("无法获取应用配置目录：{error}"))
}

fn library_from_store(mut store: TemplateStore) -> Result<TemplateLibrary, String> {
    let official = official_template()?;
    if store.selected_template_id != OFFICIAL_TEMPLATE_ID
        && !store
            .templates
            .iter()
            .any(|template| template.template_id == store.selected_template_id)
    {
        store.selected_template_id = OFFICIAL_TEMPLATE_ID.into();
    }
    let mut templates = vec![official];
    templates.extend(store.templates);
    Ok(TemplateLibrary {
        selected_template_id: store.selected_template_id,
        templates,
    })
}

fn find_template(store: &TemplateStore, template_id: &str) -> Result<ProjectTemplate, String> {
    if template_id == OFFICIAL_TEMPLATE_ID {
        return official_template();
    }
    store
        .templates
        .iter()
        .find(|template| template.template_id == template_id)
        .cloned()
        .ok_or_else(|| "所选模板不存在，请重新选择。".into())
}

fn remove_custom_template(store: &mut TemplateStore, template_id: &str) -> Result<(), String> {
    if template_id == OFFICIAL_TEMPLATE_ID {
        return Err("官方模板不能删除。".into());
    }
    let original_len = store.templates.len();
    store
        .templates
        .retain(|template| template.template_id != template_id);
    if store.templates.len() == original_len {
        return Err("要删除的模板不存在。".into());
    }
    if store.selected_template_id == template_id {
        store.selected_template_id = OFFICIAL_TEMPLATE_ID.into();
    }
    Ok(())
}

#[tauri::command]
fn get_template_library(app: tauri::AppHandle) -> Result<TemplateLibrary, String> {
    let store = load_template_store(&app_config_dir(&app)?)?;
    library_from_store(store)
}

#[tauri::command]
fn select_template(app: tauri::AppHandle, template_id: String) -> Result<ProjectTemplate, String> {
    let config_dir = app_config_dir(&app)?;
    let mut store = load_template_store(&config_dir)?;
    let template = find_template(&store, &template_id)?;
    store.selected_template_id = template_id;
    save_template_store(&config_dir, &store)?;
    Ok(template)
}

fn generated_template_id() -> String {
    let millis = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis())
        .unwrap_or_default();
    format!("custom-{millis}")
}

fn validate_path_component<'a>(value: &'a str, label: &str) -> Result<&'a str, String> {
    let name = value.trim();
    if name.is_empty() {
        return Err(format!("{label}不能为空。"));
    }
    if name.ends_with('.') || name.ends_with(' ') {
        return Err(format!("{label}不能以句点或空格结尾。"));
    }
    if let Some(character) = name
        .chars()
        .find(|character| character.is_control() || "<>:\"/\\|?*".contains(*character))
    {
        return Err(format!("{label}包含不允许的字符：{character}"));
    }
    let stem = name.split('.').next().unwrap_or(name).to_ascii_uppercase();
    let reserved = matches!(stem.as_str(), "CON" | "PRN" | "AUX" | "NUL")
        || stem
            .strip_prefix("COM")
            .or_else(|| stem.strip_prefix("LPT"))
            .is_some_and(|number| {
                matches!(number, "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9")
            });
    if reserved {
        return Err(format!("{label}是系统保留名称，请更换。"));
    }
    Ok(name)
}

fn normalize_folder_nodes(
    nodes: &mut [FolderNode],
    depth: usize,
    total: &mut usize,
) -> Result<(), String> {
    if depth > 8 {
        return Err("目录层级不能超过 8 层。".into());
    }
    let mut sibling_names = HashSet::new();
    for node in nodes {
        *total += 1;
        if *total > 200 {
            return Err("单个模板最多包含 200 个文件夹。".into());
        }
        node.name = validate_path_component(&node.name, "文件夹名称")?.into();
        let key = node.name.to_lowercase();
        if !sibling_names.insert(key) {
            return Err(format!("同一级目录中存在重复名称：{}", node.name));
        }
        normalize_folder_nodes(&mut node.children, depth + 1, total)?;
    }
    Ok(())
}

fn normalize_custom_template(template: &mut ProjectTemplate) -> Result<(), String> {
    template.template_name = validate_path_component(&template.template_name, "模板名称")?.into();
    if template.template_name.chars().count() > 50 {
        return Err("模板名称不能超过 50 个字符。".into());
    }
    if template.folders.is_empty() {
        return Err("模板至少需要一个文件夹。".into());
    }
    let mut total = 0;
    normalize_folder_nodes(&mut template.folders, 1, &mut total)?;
    template.template_version = 1;
    template.root_pattern = ROOT_PATTERN.into();
    template.naming_rules.clear();
    template.is_official = false;
    Ok(())
}

#[tauri::command]
fn save_template(
    app: tauri::AppHandle,
    mut template: ProjectTemplate,
) -> Result<TemplateLibrary, String> {
    if template.template_id == OFFICIAL_TEMPLATE_ID || template.is_official {
        return Err("官方模板不能直接修改，请先基于它创建自定义模板。".into());
    }
    normalize_custom_template(&mut template)?;
    let config_dir = app_config_dir(&app)?;
    let mut store = load_template_store(&config_dir)?;
    if store.templates.iter().any(|existing| {
        existing.template_id != template.template_id
            && existing
                .template_name
                .eq_ignore_ascii_case(&template.template_name)
    }) {
        return Err("已有同名模板，请更换名称。".into());
    }
    if template.template_id.trim().is_empty() {
        template.template_id = generated_template_id();
    }
    if let Some(existing) = store
        .templates
        .iter_mut()
        .find(|existing| existing.template_id == template.template_id)
    {
        *existing = template.clone();
    } else {
        store.templates.push(template.clone());
    }
    store.selected_template_id = template.template_id;
    save_template_store(&config_dir, &store)?;
    library_from_store(store)
}

#[tauri::command]
fn delete_template(app: tauri::AppHandle, template_id: String) -> Result<TemplateLibrary, String> {
    let config_dir = app_config_dir(&app)?;
    let mut store = load_template_store(&config_dir)?;
    remove_custom_template(&mut store, &template_id)?;
    save_template_store(&config_dir, &store)?;
    library_from_store(store)
}

fn validate_project_date(value: &str) -> Result<(), String> {
    if value.len() != 8 || !value.bytes().all(|byte| byte.is_ascii_digit()) {
        return Err("日期必须是有效的 8 位日期，例如 20260714。".into());
    }
    NaiveDate::parse_from_str(value, "%Y%m%d")
        .map(|_| ())
        .map_err(|_| "日期必须是有效的 8 位日期，例如 20260714。".into())
}

fn validate_project_name(value: &str) -> Result<&str, String> {
    validate_path_component(value, "项目名称")
}

fn ensure_directory(path: &Path, created: &mut usize, existing: &mut usize) -> Result<(), String> {
    if path.exists() {
        if path.is_dir() {
            *existing += 1;
            return Ok(());
        }
        return Err(format!("同名项目已存在，但不是文件夹：{}", path.display()));
    }
    fs::create_dir(path).map_err(|error| format!("无法创建目录 {}：{error}", path.display()))?;
    *created += 1;
    Ok(())
}

fn create_children(
    parent: &Path,
    nodes: &[FolderNode],
    created: &mut usize,
    existing: &mut usize,
) -> Result<(), String> {
    for node in nodes {
        let child = parent.join(&node.name);
        ensure_directory(&child, created, existing)?;
        create_children(&child, &node.children, created, existing)?;
    }
    Ok(())
}

fn create_project_impl(
    request: &CreateProjectRequest,
    template: &ProjectTemplate,
) -> Result<CreateProjectResult, String> {
    validate_project_date(&request.project_date)?;
    let project_name = validate_project_name(&request.project_name)?;
    let target_root = PathBuf::from(&request.target_root);
    if !target_root.is_dir() {
        return Err(format!(
            "保存位置不存在或不可访问：{}",
            target_root.display()
        ));
    }

    let root_name = template
        .root_pattern
        .replace("{date}", &request.project_date)
        .replace("{project_name}", project_name);
    let project_path = target_root.join(root_name);
    let mut created_count = 0;
    let mut existing_count = 0;
    ensure_directory(&project_path, &mut created_count, &mut existing_count)?;
    create_children(
        &project_path,
        &template.folders,
        &mut created_count,
        &mut existing_count,
    )?;

    Ok(CreateProjectResult {
        project_path: project_path.to_string_lossy().into_owned(),
        created_count,
        existing_count,
    })
}

#[tauri::command]
fn create_project(
    app: tauri::AppHandle,
    request: CreateProjectRequest,
) -> Result<CreateProjectResult, String> {
    let store = load_template_store(&app_config_dir(&app)?)?;
    let template = find_template(&store, &request.template_id)?;
    let result = create_project_impl(&request, &template)?;
    if request.open_after {
        app.opener()
            .open_path(&result.project_path, None::<&str>)
            .map_err(|error| format!("目录已生成，但无法打开项目目录：{error}"))?;
    }
    Ok(result)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            get_template_library,
            select_template,
            save_template,
            delete_template,
            create_project
        ])
        .run(tauri::generate_context!())
        .expect("failed to run video folder generator");
}

#[cfg(test)]
mod tests {
    use super::*;

    fn request(root: &Path, template_id: &str) -> CreateProjectRequest {
        CreateProjectRequest {
            target_root: root.to_string_lossy().into_owned(),
            project_name: "测试项目".into(),
            project_date: "20260714".into(),
            open_after: false,
            template_id: template_id.into(),
        }
    }

    fn custom_template() -> ProjectTemplate {
        ProjectTemplate {
            template_id: "custom-test".into(),
            template_version: 1,
            template_name: "测试模板".into(),
            root_pattern: ROOT_PATTERN.into(),
            folders: vec![FolderNode {
                name: "素材".into(),
                children: vec![FolderNode {
                    name: "视频".into(),
                    children: Vec::new(),
                }],
            }],
            naming_rules: Vec::new(),
            is_official: false,
        }
    }

    #[test]
    fn embedded_template_contains_twenty_fixed_folders_and_document() {
        let template = official_template().unwrap();
        fn flatten(nodes: &[FolderNode], paths: &mut Vec<String>, prefix: &str) {
            for node in nodes {
                let path = if prefix.is_empty() {
                    node.name.clone()
                } else {
                    format!("{prefix}/{}", node.name)
                };
                paths.push(path.clone());
                flatten(&node.children, paths, &path);
            }
        }
        let mut paths = Vec::new();
        flatten(&template.folders, &mut paths, "");
        assert_eq!(paths.len(), 20);
        assert!(paths.contains(&"3.素材/文档".to_string()));
        assert!(!paths.iter().any(|path| path.contains("时间_机型_机位")));
        assert!(template.is_official);
    }

    #[test]
    fn validates_dates_and_cross_platform_names() {
        assert!(validate_project_date("20240229").is_ok());
        assert!(validate_project_date("20230229").is_err());
        assert!(validate_project_name("常彧老师播客").is_ok());
        assert!(validate_project_name("采访/剪辑").is_err());
        assert!(validate_project_name("CON").is_err());
    }

    #[test]
    fn rejects_duplicate_siblings_and_empty_templates() {
        let mut duplicate = custom_template();
        duplicate.folders.push(FolderNode {
            name: "素材".into(),
            children: Vec::new(),
        });
        assert!(normalize_custom_template(&mut duplicate).is_err());

        let mut empty = custom_template();
        empty.folders.clear();
        assert!(normalize_custom_template(&mut empty).is_err());
    }

    #[test]
    fn saves_and_loads_custom_template_store() {
        let temp = tempfile::tempdir().unwrap();
        let store = TemplateStore {
            selected_template_id: "custom-test".into(),
            templates: vec![custom_template()],
        };
        save_template_store(temp.path(), &store).unwrap();
        let loaded = load_template_store(temp.path()).unwrap();
        assert_eq!(loaded.selected_template_id, "custom-test");
        assert_eq!(loaded.templates[0].template_name, "测试模板");
    }

    #[test]
    fn deletes_custom_template_and_restores_official_selection() {
        let mut store = TemplateStore {
            selected_template_id: "custom-test".into(),
            templates: vec![custom_template()],
        };
        remove_custom_template(&mut store, "custom-test").unwrap();
        assert!(store.templates.is_empty());
        assert_eq!(store.selected_template_id, OFFICIAL_TEMPLATE_ID);
        assert!(remove_custom_template(&mut store, OFFICIAL_TEMPLATE_ID).is_err());
    }

    #[test]
    fn first_run_creates_twenty_one_and_second_run_detects_existing() {
        let temp = tempfile::tempdir().unwrap();
        let template = official_template().unwrap();
        let first =
            create_project_impl(&request(temp.path(), OFFICIAL_TEMPLATE_ID), &template).unwrap();
        assert_eq!((first.created_count, first.existing_count), (21, 0));
        assert!(Path::new(&first.project_path).join("3.素材/文档").is_dir());

        let second =
            create_project_impl(&request(temp.path(), OFFICIAL_TEMPLATE_ID), &template).unwrap();
        assert_eq!((second.created_count, second.existing_count), (0, 21));
    }

    #[test]
    fn custom_template_drives_project_generation() {
        let temp = tempfile::tempdir().unwrap();
        let template = custom_template();
        let result = create_project_impl(&request(temp.path(), "custom-test"), &template).unwrap();
        assert_eq!((result.created_count, result.existing_count), (3, 0));
        assert!(Path::new(&result.project_path).join("素材/视频").is_dir());
        assert!(!Path::new(&result.project_path).join("1.工程文件").exists());
    }

    #[test]
    fn does_not_replace_a_file_with_a_directory() {
        let temp = tempfile::tempdir().unwrap();
        fs::write(temp.path().join("20260714_测试项目"), b"occupied").unwrap();
        let template = official_template().unwrap();
        assert!(
            create_project_impl(&request(temp.path(), OFFICIAL_TEMPLATE_ID), &template).is_err()
        );
    }
}
