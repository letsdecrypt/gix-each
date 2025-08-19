# gix-each
fetch all git repos in all subdirectories

# features
1. gix
2. tasks: parallel or serial; by rayon or tokio, by `-j/--jobs` param
3. colorful output: by indicatif
4. `directory depth` support: if the dir is not a `.git` dir, check subs and depth-1, by `-d/--depth` param
5. commands: refer gix

# todo 
- [ ] fetch is not enough, I need `pull`!
- [ ] progress bar
- [ ] support `-r/--recursive`
- [ ] support `-s/--submodule`
- [ ] better output
