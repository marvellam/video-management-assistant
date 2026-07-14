use chrono::NaiveDate;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use tauri_plugin_opener::OpenerExt;

const TEMPLATE_JSON: &str = include_str!("../../template.json");

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all(serialize = "camelCase", deserialize = "snake_case"))]
struct ProjectTemplate {
    template_version: u32,
    template_name: String,
    root_pattern: String,
    folders: Vec<FolderNode>,
    #[serde(default)]
    naming_rules: Vec<NamingRule>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
struct FolderNode {
    name: String,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    children: Vec<FolderNode>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all(serialize = "camelCase", deserialize = "snake_case"))]
struct NamingRule {
    applies_to: String,
    rule: String,
    create_as_folder: bool,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct CreateProjectRequest {
    target_root: String,
    project_name: String,
    project_date: String,
    open_after: bool,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct CreateProjectResult {
    project_path: String,
    created_count: usize,
    existing_count: usize,
}

fn parse_template() -> Result<ProjectTemplate, String> {
    serde_json::from_str(TEMPLATE_JSON).map_err(|error| format!("目录模板无效：{error}"))
}

#[tauri::command]
fn get_template() -> Result<ProjectTemplate, String> {
    parse_template()
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
    let name = value.trim();
    if name.is_empty() {
        return Err("项目名称不能为空。".into());
    }
    if name.ends_with('.') || name.ends_with(' ') {
        return Err("项目名称不能以句点或空格结尾。".into());
    }
    if let Some(character) = name
        .chars()
        .find(|character| character.is_control() || "<>:\"/\\|?*".contains(*character))
    {
        return Err(format!("项目名称包含不允许的字符：{character}"));
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
        return Err("项目名称是系统保留名称，请更换。".into());
    }
    Ok(name)
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

fn create_project_impl(request: &CreateProjectRequest) -> Result<CreateProjectResult, String> {
    validate_project_date(&request.project_date)?;
    let project_name = validate_project_name(&request.project_name)?;
    let template = parse_template()?;
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
    let result = create_project_impl(&request)?;
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
        .invoke_handler(tauri::generate_handler![get_template, create_project])
        .run(tauri::generate_context!())
        .expect("failed to run video folder generator");
}

#[cfg(test)]
mod tests {
    use super::*;

    fn request(root: &Path) -> CreateProjectRequest {
        CreateProjectRequest {
            target_root: root.to_string_lossy().into_owned(),
            project_name: "测试项目".into(),
            project_date: "20260714".into(),
            open_after: false,
        }
    }

    #[test]
    fn embedded_template_contains_twenty_fixed_folders_and_document() {
        let template = parse_template().unwrap();
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
    fn first_run_creates_twenty_one_and_second_run_detects_existing() {
        let temp = tempfile::tempdir().unwrap();
        let first = create_project_impl(&request(temp.path())).unwrap();
        assert_eq!((first.created_count, first.existing_count), (21, 0));
        assert!(Path::new(&first.project_path).join("3.素材/文档").is_dir());

        let second = create_project_impl(&request(temp.path())).unwrap();
        assert_eq!((second.created_count, second.existing_count), (0, 21));
    }

    #[test]
    fn does_not_replace_a_file_with_a_directory() {
        let temp = tempfile::tempdir().unwrap();
        fs::write(temp.path().join("20260714_测试项目"), b"occupied").unwrap();
        assert!(create_project_impl(&request(temp.path())).is_err());
    }
}
