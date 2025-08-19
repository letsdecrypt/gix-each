use clap::Parser;
use rayon::prelude::*;
use rayon::ThreadPoolBuilder;
use std::fs;
use std::path::Path;
use std::path::PathBuf;

#[derive(Debug, Parser)]
#[command(about, author, version)]
struct Args {
    /// runs in serial mode, by default cli runs in parallel mode
    #[arg(short = 's', long, default_value_t = false)]
    serial: bool,
    /// max number of jobs to run in parallel, by default num of cpus
    #[arg(short = 'j', long, default_value_t = 0)]
    jobs: u16,
    /// depth of subdirectories to search for git repos
    #[arg(short = 'd', long, default_value_t = 1)]
    depth: u8,
    /// path to directory to search for git repos, by default current working directory
    path: Option<PathBuf>,
}

fn list_subdirectories<P: AsRef<Path>>(path: P) -> Result<Vec<String>, std::io::Error> {
    let mut directories = Vec::new();

    for entry in fs::read_dir(path)? {
        let entry = entry?;
        let path = entry.path();

        if path.is_dir() {
            if let Some(name) = path.file_name() {
                directories.push(name.to_string_lossy().to_string());
            }
        }
    }

    Ok(directories)
}

fn fetch_repo<P: AsRef<Path>>(path: P, dir: &String) {
    let repo = match gix::open(path.as_ref()) {
        Ok(repo) => repo,
        Err(e) => {
            eprintln!("{}, 错误：目录非git仓库.{}", dir, e);
            return;
        }
    };
    let remote_result = match repo.find_default_remote(gix::remote::Direction::Fetch) {
        Some(remote) => remote,
        None => {
            eprintln!("{}, 错误：未配置remote", dir);
            return;
        }
    };
    let remote = match remote_result {
        Ok(remote) => remote,
        Err(e) => {
            eprintln!("{}, 错误：remote获取失败, {}", dir, e);
            return;
        }
    };
    let p = gix::progress::Discard;
    let outcome_result = remote
        .connect(gix::remote::Direction::Fetch)
        .unwrap()
        .prepare_fetch(
            &mut gix::progress::Discard,
            gix::remote::ref_map::Options::default(),
        )
        .unwrap()
        .receive(p, &gix::interrupt::IS_INTERRUPTED);
    match outcome_result {
        Ok(outcome) => {
            println!(
                "{}: 拉取成功完成! 接收到 {} 个对象",
                dir,
                outcome.ref_map.remote_refs.len()
            );
        }
        Err(e) => {
            eprintln!("{}: 拉取失败: {}", dir, e);
        }
    }
}
fn main() {
    let args = Args::parse();
    let base_path = args.path.unwrap_or_else(|| ".".into());

    if args.jobs > 0 {
        ThreadPoolBuilder::new()
            .num_threads(args.jobs as usize)
            .build_global()
            .expect("Failed to configure thread pool");
    }

    match list_subdirectories(&base_path) {
        Ok(dirs) => {
            if args.serial {
                // 顺序执行
                dirs.iter().for_each(|dir| {
                    let full_path = Path::new(&base_path).join(dir.clone());
                    fetch_repo(full_path, dir);
                });
            } else {
                // 并行执行
                dirs.par_iter().for_each(|dir| {
                    let full_path = Path::new(&base_path).join(dir.clone());
                    fetch_repo(full_path, dir);
                });
            }
        }
        Err(e) => eprintln!("错误: {}", e),
    }
}
