function okta_expiration_prompt() {

  if [ -f ~/.okta/.current-session ]; then
    okta_expiration_prompt_new
  elif [ -f ~/.aws/credentials ]; then
    okta_expiration_prompt_old
  else
    echo " \[\e[31m\]OKTA:!!\[\e[39m\] "
  fi
}

function okta_expiration_prompt_new() {
  f=~/.okta/.current-session
  source $f
  if [ x$AWS_PROFILE == x$OKTA_AWS_CLI_PROFILE ]; then
    touch -d $OKTA_AWS_CLI_EXPIRY "/dev/shm/.$AWS_PROFILE"
  fi
  if [ -f "/dev/shm/.$AWS_PROFILE" ]; then
    :
  else
    okta_expiration_prompt_old
    return
  fi

  mod_date=$(stat --format=%Y "/dev/shm/.$AWS_PROFILE")
  cur_date=$( date +%s ) # current date

  e=$(( ($mod_date - $cur_date)/60 )) # minutes left
  if [ $e -lt 0 ]; then
    return
  elif [ $e -lt 15 ]; then
    clr=31
  elif [ $e -lt 40 ]; then
    clr=93
  else
    clr=92
  fi

  echo " \[\e[${clr}m\]OKTA:$e\[\e[39m\] "
}

function okta_expiration_prompt_old() {
  f=~/.aws/credentials
  mod_date=$( stat --format=%Y $f ) # file modification date
  cur_date=$( date +%s ) # current date

  e=$(( 60 - ($cur_date - $mod_date)/60 )) # minutes left
  if [ $e -lt 0 ]; then
    return
  elif [ $e -lt 15 ]; then
    clr=31
  elif [ $e -lt 40 ]; then
    clr=93
  else
    clr=92
  fi

  echo " \[\e[${clr}m\]OKTA:$e\[\e[39m\] "
}
