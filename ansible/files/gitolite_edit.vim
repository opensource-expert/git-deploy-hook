"
" vim script that helps to modify gitolite.conf (edited by redmine)
"
" Format:
"  v idented with spaces
"  |repo    project_name/repository_name
"  |  RW+                            = redmine_user_10 redmine_user_5
"  |  R                              = redmine_user_5_deploy_key_2
"  |  config redminegitolite.projectid = project_name
"  |  config redminegitolite.repositoryid = repository_name
"  |  config http.uploadpack = false
"  |  config http.receivepack = false
"  |  config multimailhook.enabled = false
"
"
" Usage: vim -u path/to/gitolite_edit.vim  \
"   -c 'let r=GitoLiteUpdateRepos("your_repos_name", "deploy.prod.uri", "some value here")' \
"   -c w \
"   -c 'exe "silent !echo ".r' \
"   -c q \
"   conf/gitolite.conf
"

func! GitoLiteUpdateRepos(repos, config, value)
  " search our repos
  let lnum = search('^repo\s\+'.a:repos.'$', 'e')
  if lnum == 0
    return "not_found"
  endif

  " search end of repos def
  let lnum_end = search('^$')

  " move back to the repos start
  call cursor(lnum, 1)

  " search the config if exists
  let lnum_config = search('^\s\+config\s\+'.a:config.' =', '', lnum_end-1)

  if lnum_config != 0
    " config_key already present, updating

    " get current line content
    let l = getline('.')

    " position at the next word after the equal sign
    exe ":norm f=w"
    if getcurpos()[1] == lnum_config
      " some word after equal sign
      exe "norm C".a:value."\e"
    else
      " too far, we move back
      exe "norm kA".a:value."\e"
    endif

    " compare the line
    let new = getline('.')
    if l != new
      let ret = "updated"
    else
      let ret = "unchanged"
    endif
  else
    " config_key not found, inserting at the end of the block
    exe ":norm ".lnum_end."GO  config ".a:config." = ".a:value."\e"
    let ret = "inserted"
  endif

  return ret
endf
