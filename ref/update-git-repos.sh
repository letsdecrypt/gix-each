#!/bin/bash

# 脚本名称: update-git-repos.sh
# 功能: 更新当前目录下所有子目录中的git仓库

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的信息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查目录是否为git仓库
is_git_repo() {
    local dir="$1"
    if [ -d "$dir/.git" ] || (cd "$dir" 2>/dev/null && git rev-parse --git-dir >/dev/null 2>&1); then
        return 0
    else
        return 1
    fi
}

# 更新单个git仓库
update_repo() {
    local repo_dir="$1"
    local repo_name=$(basename "$repo_dir")
    
    print_info "正在处理仓库: $repo_name"
    
    # 进入仓库目录
    cd "$repo_dir" || {
        print_error "无法进入目录: $repo_dir"
        return 1
    }
    
    # 获取当前分支
    local current_branch=$(git branch --show-current 2>/dev/null)
    if [ -z "$current_branch" ]; then
        current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    fi
    
    if [ -z "$current_branch" ] || [ "$current_branch" = "HEAD" ]; then
        print_warning "仓库 $repo_name 没有明确的当前分支，跳过更新"
        cd - >/dev/null
        return 0
    fi
    
    print_info "当前分支: $current_branch"
    
    # 获取更新前的状态
    local before_status=$(git rev-parse HEAD 2>/dev/null)
    
    # 获取远程更新
    print_info "获取远程更新..."
    git fetch --all
    
    if [ $? -ne 0 ]; then
        print_error "获取远程更新失败: $repo_name"
        cd - >/dev/null
        return 1
    fi
    
    # 检查是否有更新
    local remote_commit=$(git rev-parse "origin/$current_branch" 2>/dev/null)
    local local_commit=$(git rev-parse "$current_branch" 2>/dev/null)
    
    if [ "$local_commit" != "$remote_commit" ]; then
        print_info "检测到更新，正在拉取最新代码..."
        
        # 拉取最新代码
        git pull --recurse-submodules origin "$current_branch"
        
        if [ $? -eq 0 ]; then
            local after_status=$(git rev-parse HEAD 2>/dev/null)
            if [ "$before_status" != "$after_status" ]; then
                print_success "仓库 $repo_name 更新成功"
            else
                print_info "仓库 $repo_name 已经是最新的"
            fi
        else
            print_error "更新仓库 $repo_name 失败"
        fi
    else
        print_info "仓库 $repo_name 已经是最新的"
    fi
    
    # 返回原目录
    cd - >/dev/null
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo "选项:"
    echo "  -h, --help     显示此帮助信息"
    echo "  -v, --verbose  显示详细信息"
    echo "  -n, --dry-run  模拟运行，不实际执行更新"
    echo ""
    echo "功能: 更新当前目录下所有子目录中的git仓库"
}

# 主函数
main() {
    local verbose=false
    local dry_run=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -n|--dry-run)
                dry_run=true
                shift
                ;;
            *)
                print_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 检查当前目录是否存在
    if [ ! -d "." ]; then
        print_error "当前目录不存在"
        exit 1
    fi
    
    print_info "开始更新当前目录下的所有git仓库..."
    
    # 统计变量
    local total_repos=0
    local updated_repos=0
    local failed_repos=0
    
    # 遍历当前目录下的所有子目录
    for dir in */; do
        if [ -d "$dir" ]; then
            if is_git_repo "$dir"; then
                total_repos=$((total_repos + 1))
                
                if [ "$dry_run" = true ]; then
                    print_info "[模拟] 将更新仓库: $(basename "$dir")"
                else
                    update_repo "$dir"
                    if [ $? -eq 0 ]; then
                        updated_repos=$((updated_repos + 1))
                    else
                        failed_repos=$((failed_repos + 1))
                    fi
                fi
            else
                if [ "$verbose" = true ]; then
                    print_info "跳过非git目录: $dir"
                fi
            fi
        fi
    done
    
    # 处理隐藏目录（以.开头的目录）
    for dir in .*/; do
        if [ "$dir" != "./" ] && [ "$dir" != "../" ]; then
            if [ -d "$dir" ]; then
                if is_git_repo "$dir"; then
                    total_repos=$((total_repos + 1))
                    
                    if [ "$dry_run" = true ]; then
                        print_info "[模拟] 将更新仓库: $(basename "$dir")"
                    else
                        update_repo "$dir"
                        if [ $? -eq 0 ]; then
                            updated_repos=$((updated_repos + 1))
                        else
                            failed_repos=$((failed_repos + 1))
                        fi
                    fi
                else
                    if [ "$verbose" = true ]; then
                        print_info "跳过非git目录: $dir"
                    fi
                fi
            fi
        fi
    done
    
    # 显示统计信息
    print_info "处理完成!"
    print_info "总仓库数: $total_repos"
    if [ "$dry_run" = false ]; then
        print_success "成功更新: $updated_repos"
        if [ $failed_repos -gt 0 ]; then
            print_error "更新失败: $failed_repos"
        fi
    fi
}

# 执行主函数
main "$@"
