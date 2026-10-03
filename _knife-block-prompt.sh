function knife_block_prompt() {
if [[ -f ~/.chef/knife.rb ]]; then
  knife_env=$( basename $( readlink ~/.chef/knife.rb  ) | awk -F"[-.]" '{print $2}' )
  case $knife_env in
      *prod*)    clr=31;;
      *opsdev*)  clr=92;;
      *)         clr=93;;
  esac
  echo " \[\e[${clr}m\]K:$knife_env\[\e[39m\] "
fi
}
