# .cshrc file
# $Id: //hw/nv/env/.cshrc#88 $

######
# UNIX UPDATE PROCEDURE:
# > envupdate -m
#
# CYGWIN UPDATE PROCEDURE:
# * map \\roswell\nv to Z:
# > /cygdrive/z/bin/envupdate -m


##echo "trace_c00"

#######
# CUSTOMIZE THESE ENVIRONMENT VARIABLES
#######

# If DISPLAY is not set already, it will be automatically set to DEFAULTDISPLAY
# Comment out this line if you don't want this functionality.
setenv DEFAULTDISPLAY my_unix_box:0.0

# to stop that nasty .flexlmrc file from being created 
setenv FLEXLM_NO_CKOUT_INSTALL_LIC 1
#tell synopsys tools not look for obsoleted keys 
setenv SCL_AUTHORIZE_LIST 1

# set the Novas idle license timeout to 15 minutes
setenv NOVAS_IDLE_LICENSE_CHECKBACK 15

# silences an annoying pop-up dialog
setenv NOVAS_IDLE_LICENSE_CHECKBACK_SILENCE 1

# set this to point to your favorite printer
setenv PRINTER     my_printer

if (! $?USE_TCSH) then
  # set to 0 if you don't want TCSH
  setenv USE_TCSH    1
endif
######
#
set hostname = `/bin/hostname`
setenv HNAME $hostname

if (! $USE_TCSH) then
  unsetenv TCSH
else if (-x /usr/bin/tcsh) then
  setenv TCSH /usr/bin/tcsh
else if (-x /bin/tcsh) then
  setenv TCSH /bin/tcsh
else
  echo "tcsh not found, using $shell"
endif

setenv INIT_TCSH 0
if ($?TCSH) then
  if ($?prompt) then
    if ((-x $TCSH) && ($?term) && ("$prompt" != "")) then
      # interactive session
      if ($shell == "/bin/csh") then
        # invoke tcsh shell
        setenv SHELL $TCSH
        exec $TCSH
      else if ($shell =~ */bin/tcsh) then 
        # init tcsh shell
        setenv SHELL $TCSH
        setenv INIT_TCSH 1
      endif
    endif
  endif
endif

setenv OSTYPE_RAW `/bin/uname -s`
setenv OSTYPE $OSTYPE_RAW
set cygwin = `/bin/uname | /bin/grep -i 'cygwin'`
if ($OSTYPE == "Linux") then
 # linux
else if ($OSTYPE == "SunOS") then
 # sun
#else if ($OSTYPE == "CYGWIN_NT-5.0" || $OSTYPE == "CYGWIN_NT-5.1" || $OSTYPE == "CYGWIN_NT-5.2" || $OSTYPE == "CYGWIN_NT-6.0" || $OSTYPE == "CYGWIN_NT-6.0-WOW64") then
else if ( $cygwin != '' ) then
 setenv OSTYPE Win32
 setenv BASH_ENV ~/.bash_env
 setenv ENV ~/.bash_env
else
 echo "WARNING: can't determine OS type, defaulting to SunOS"
 setenv OSTYPE SunOS
endif

# auto log out of lsf interactive shell, unless running in interactive queue
if ($?LSB_QUEUE) then
  if ($LSB_QUEUE == "o_pri_interactive" || $QSUB_VQUEUE_ROOT == "interactive_asic") then
    unset autologout
  else
    set autologout = 30
  endif
else
  unset autologout
endif
if ($?LSB_INTERACTIVE) then
    if ($LSB_INTERACTIVE == 'Y') then
        unset autologout
    endif
endif

##echo "trace_c02"

setenv	ENSCRIPT "-fTimes-Roman12 "	# set default font and header
setenv  MANPAGER more
setenv	MANPATH /home/utils/man:/usr/man:${HOME}/man	
if (-e /usr/local/man) setenv MANPATH ${MANPATH}:/usr/local/man
if (-e /usr/share/man) setenv MANPATH ${MANPATH}:/usr/share/man
if (-e /usr/local/deskset/man) setenv MANPATH ${MANPATH}:/usr/local/deskset/man
if (-e /usr/X11R6/man) setenv MANPATH ${MANPATH}:/usr/X11R6/man
setenv	GFLAGS	-r11

# whitebox workaround - whitebox sets LANG to en_US.UTF-8 which confuses man and perldoc
unsetenv LANG

##echo "trace_c022"

#if ($?EDITOR) then
#  unsetenv EDITOR
#endif
setenv EDITOR vi

##echo "trace_c024"

# On Win32, preserve the Windows system path. On other systems, start fresh.
if ($OSTYPE != "Win32") then
  set path = ""
else
  if ($?SYSPATH) then
    setenv PATH "$SYSPATH"
  else
    # save default path so that if we source again, we can start the path here
    setenv SYSPATH "$PATH"
  endif
endif

# common across all platforms
set path = ( \
  ~/bin \
  /home/utils/bin \
  /bin \
  /home/gnu/bin \
  /usr/bin \
  . \
  $path:q \
)

# common across unix platforms
if ($OSTYPE == "Linux" || $OSTYPE == "SunOS") then
  set path = ( \
    $path:q \
    /sbin \
    /usr/sbin \
    /usr/ucb \
    /usr/ccs/bin \
    /usr/lib \
    /etc \
    /home/nv/bin \
  )
endif

if ($OSTYPE == "Linux") then
  # linux-specific paths
  set path = ( \
    $path:q \
    /usr/bin/X11 \
    /usr/local/lsf/bin \
  )
endif

if ($OSTYPE == "SunOS") then
  # sun-specific paths
  set path = ( \
    $path:q \
    )
endif

##echo "trace_c025"

if ($OSTYPE == "Win32") then
  if (-d "/cygdrive/c/WINDOWS") then
    set cdrive = "/cygdrive/c"
  else if (-d "/cygdrive/x/WINDOWS") then
    # under citrix, windows apps are on x:, not c:
    set cdrive = "/cygdrive/x"
  else
    echo "ERROR: can't find windows dir!"
    set cdrive = "/cygdrive/c"
  endif

  if (-d "$cdrive/Program Files (x86)") then
    set progfiles32b = "Program Files (x86)"
  else
    set progfiles32b = "Program Files"
  endif 
  
  # Win32-specific paths
  set path = ( \
    $path:q \
    $cdrive/windows/system32 \
    $cdrive/windows/system32/wbem \
  )

  # these paths may or may not be present, only add them to the $path if they exist

  # note - we used to have a mix of windows-style and unix-style paths in $path but this
  # seemed to be the cause of intermittent lengthy delays in running a program.

  # the ":q" suffix in $path quotes the previous path names, so we can handle
  # path directories that contain spaces.

  # in 64b windows, native 64b programs live in Program Files, 32b programs live in Program Files (x86) .
  # hard code Program Files for programs (like Perforce) that have both 32b and 64b versions.  For
  # programs with only a 32b version, use the progfiles32b env variable.

  foreach testvar ( \
                    "$cdrive/$progfiles32b/Microsoft Visual Studio 8/Common7\IDE" \
                    "$cdrive/$progfiles32b/Microsoft Visual Studio 8/VC/bin" \
                    "$cdrive/$progfiles32b/Microsoft Visual Studio .NET 2003/Vc7/bin" \
                    "$cdrive/progra~1/micros~3/vc98/bin" \
                    "$cdrive/progra~1/micros~3/common/msdev98/bin" \
                    "$cdrive/Program Files/Perforce" \
                    "$cdrive/$progfiles32b/Microsoft Office/Office14" \
                    "$cdrive/$progfiles32b/Microsoft Office/Office13" \
                    "$cdrive/$progfiles32b/Microsoft Office/Office12" \
                    "$cdrive/$progfiles32b/Microsoft Office/Office11" \
                    "$cdrive/$progfiles32b/Microsoft Office/Office10" \
                    "$cdrive/$progfiles32b/Microsoft Office/Visio14" \
                    "$cdrive/$progfiles32b/Microsoft Office/Visio13" \
                    "$cdrive/$progfiles32b/Microsoft Office/Visio12" \
                    "$cdrive/$progfiles32b/Microsoft Office/Visio11" \
                    "$cdrive/$progfiles32b/Microsoft Office/Visio10" \
                    "$cdrive/$progfiles32b/Internet Explorer" \
                    "$cdrive/$progfiles32b/Windows NT/Accessories" \
                    "$cdrive/$progfiles32b/Adobe/Reader 10.0/Reader" \
                    "$cdrive/$progfiles32b/Adobe/Acrobat 9.0/Reader" \
                    "$cdrive/$progfiles32b/Adobe/Acrobat 8.0/Reader" \
                    "$cdrive/$progfiles32b/Adobe/Acrobat 7.0/Reader" \
                    "$cdrive/$progfiles32b/Adobe/Acrobat 6.0/Reader" \
                    "$cdrive/$progfiles32b/Adobe/Acrobat 5.0/Reader" \
                    /home/nv/bin \
                    /home/nv/utils/cygwin/bin \
                  )
    if ( -d "$testvar" ) then
      set path = ( $path:q "$testvar" )
    endif
  end
endif

##echo "trace_c03"

if ($OSTYPE == "Linux" || $OSTYPE == "SunOS") then
  # addtopath.pl is an NVIDIA env helper — not on every host (e.g. UFLWPE).
  # Skip silently if absent so .cshrc doesn't pollute stdout for ssh-launched
  # commands (mosh-server parses that output).
  which addtopath.pl >& /dev/null
  if ($status == 0) then
    setenv LD_LIBRARY_PATH `addtopath.pl -quiet LD_LIBRARY_PATH /usr/lib ${HOME}/lib .`
  endif
endif

set OSREV=`uname -r`

##echo "trace_c031"

#umask 027 				#set default file protection
umask 002 				#set default file protection

##echo "trace_c04"

if ($OSTYPE == "Linux" || $OSTYPE == "SunOS") then
  # limit stack to 33M to give more space for data.  
  # fm_shell recommends min 32M.
  limit stacksize 33000

  # for some reason this doesn't seem to work for root
  #if (`whoami` != "root") limit stacksize unlimit
  # limit memorysize 3200000
  limit coredumpsize 1
endif

if ($OSTYPE == "SunOS") then
  if ($OSREV == "5.5") then
    limit datasize unlimit
  else
    limit datasize 3900000
    if ($?TCSH) then
     # this one is tcsh-only
      if ($shell == $TCSH) limit vmemoryuse 3800000
    endif
  endif
endif
if ($OSTYPE == "Linux") then
  limit datasize unlimit
  #Increase Max number of files user can open HR#480167
  limit descriptors unlimit
endif

##echo "trace_c05"

if ($OSTYPE == "Linux" || $OSTYPE == "SunOS") then
  # .cshrc_tools is NVIDIA env-tools sourcer — only present on BAN/SC-like
  # hosts. Skip silently elsewhere (UFLWPE etc.) to avoid stdout pollution.
  if (-e ${HOME}/.cshrc_tools) source ${HOME}/.cshrc_tools
endif

if ($OSTYPE == "Win32") then
  # Windows tool setup here
  setenv P4CONFIG .p4config

  # Need to determine cygwin version
  set cygwin_version_major=`uname -r | cut -d . -f 1`
  set cygwin_version_minor=`uname -r | cut -d . -f 2`
  # For cygwin 1.5 and below use rxvt P4EDITOR (vi does not work); for
  # cygwin 1.7 and above use vim.
  if ($cygwin_version_major == 1 && $cygwin_version_minor <= 5) then
    setenv P4EDITOR "rxvt -e vi"
  else if ($cygwin_version_major == 1 && $cygwin_version_minor >= 7) then
    setenv P4EDITOR "vim"
  endif
  setenv P4USER $USER
endif

##echo "trace_c06"

setenv PURPOSE ""

# If you're on VNC, set DISPLAY from it
if (($?VNCDESKTOP) && (! $?DISPLAY)) then
  setenv DISPLAY `echo $VNCDESKTOP | awk '{print $1}'`
endif

# If SSH_CONNECTION exists, use the client IP for DISPLAY
if (($?SSH_CONNECTION) && (! $?DISPLAY)) then
  set ssh_client_ip = `echo $SSH_CONNECTION | awk '{print $1}'`
  setenv DISPLAY $ssh_client_ip':0.0'
endif

# If you defined your own fallback, use it
if (($?DEFAULTDISPLAY) && (! $?DISPLAY)) then
  setenv DISPLAY $DEFAULTDISPLAY
endif

# If REMOTEHOST exists, use it. Not too useful, since with VNC you're not likely to be on :0.0.
if (($?REMOTEHOST) && (! $?DISPLAY)) then
  setenv DISPLAY $REMOTEHOST':0.0'
endif

if (($?REMOTE_HOSTNAME) && (! $?DISPLAY)) then
  setenv DISPLAY $REMOTE_HOSTNAME':0.0'
endif

# if (! $?DISPLAY) then
#   echo "DISPLAY not set.\n"
# endif


# source ~/.aliases  # Now zsh-only, sourced from ~/.zshrc

##echo "trace_c10"

# only do tcsh init if we're in an interactive tcsh shell
if (($?INIT_TCSH) && ($INIT_TCSH == 1)) then
  ### delete words:
  bindkey ^W	backward-delete-word
  bindkey ^[^d	delete-word		#cntrl-[ cntrl-d: delete forward word
  
  ### cursor movement in word::
  #bindkey ^[^F	forward-word
  #bindkey ^[^B	backward-word
  bindkey ^F  forward-word
  bindkey ^B  backward-word
  
  bindkey ' '	magic-space
  bindkey ^_	i-search-back		#cntrl-/ : locate the next line w/ a pattern
  
  #set	complete = enhance
  #set	autolist = ambiguous
  #set	autoexpand
  
  #set noclobber		# don't write over existing files
  uncomplete *			# flush out all file completion customizations

  set history = 100
  
  set notify
  set filec
  
  set dextract	# pop +2, etc
  set addsuffix	# file completion plus a space or /
  set correct=cmd	# correct misspelled commands
  
  set matchbeep=nomatch
  #set tty=`/bin/tty | /bin/sed 's/\/dev\/tty//'`
  if ($OSTYPE == "SunOS") set tty=`/bin/tty | /home/utils/perl-5.6.1/bin/perl5.6.1 -pe 's/\/dev\/\w+\///'`
  if ($OSTYPE == "Linux") set tty=`/usr/bin/tty | /home/utils/perl-5.8.6/bin/perl -pe 's/\/dev\/\w+\///'`
  set	histfile="$HOME/.$HNAME-$tty"
##echo "trace_t10"
  # source ${HOME}/.login
##echo "trace_t20"
else
##echo "trace_t70"
endif

##echo "trace_c80"

### VNC has been shown to set SESSION_MANAGER to a value such as tihs:
### local/unix:@/tmp/.ICE-unix/32346,unix/unix:/tmp/.ICE-unix/32346
### Such a value makes X clients slow and customers sad, when you do e.g.:
###   qsub -Is /bin/bash
###   gvim
### Unsetting SESSION_MANAGER seems to fix this.
unsetenv SESSION_MANAGER

if (-e ~/.cshrc_custom ) then
  source ~/.cshrc_custom
endif

if ( -e ~/.p4client ) then
  source ~/.p4client
endif


# termgpt integration for tcsh/csh
# Usage: Press Ctrl+G to convert natural language to shell commands
# Alternative: Use tg or termgpt aliases

# First, create the termgpt aliases for direct usage
# Try to find termgpt in PATH first, then fallback to current directory
which termgpt >& /dev/null
if ( $status == 0 ) then
    alias termgpt 'termgpt'
    alias tg 'termgpt'
else if ( -f "./termgpt" ) then
    alias termgpt './termgpt'
    alias tg './termgpt'
else if ( -f "/home/advarshney/termgpt" ) then
    # Use the full path where this script was installed from
    alias termgpt '/home/advarshney/termgpt'
    alias tg '/home/advarshney/termgpt'
endif

# Main function: Generate command and add to current history
alias termgpt-generate '    echo -n "termgpt> " ;    set _tg_prompt = "$<" ;    if ( "$_tg_prompt" != "" ) then ;        set _tg_cmd = `termgpt -p "$_tg_prompt"` ;        if ( "$_tg_cmd" != "" ) then ;            echo "$_tg_cmd" > ~/.termgpt_lastcmd ;            echo "$_tg_cmd" ;            if ( $?histfile ) then ;                history -S ;                echo "$_tg_cmd" >> $histfile ;                history -L ;            endif ;        endif ;    endif'

# Bind Ctrl+G to the generate function
bindkey -c "^G" 'termgpt-generate'

# Create a simpler version that puts command in a format ready to copy
alias termgpt-copy '\
    echo -n "termgpt> " ;\
    set _tg_prompt = "$<" ;\
    if ( "$_tg_prompt" != "" ) then ;\
        set _tg_cmd = `termgpt -p "$_tg_prompt"` ;\
        if ( "$_tg_cmd" != "" ) then ;\
            echo "$_tg_cmd" > ~/.termgpt_lastcmd ;\
            echo -n "$_tg_cmd" ;\
        endif ;\
    endif'

# Create shortcuts for the last generated command
# Note: !! is already a tcsh built-in for last command

# Alternative: Create an alias that evals the last generated command
alias tg! 'eval `cat ~/.termgpt_lastcmd`'
alias tg? 'cat ~/.termgpt_lastcmd'

# Help command to show termgpt usage
alias tghelp 'echo "termgpt usage:"; echo "  Ctrl+G    - Generate command from natural language"; echo "  UP arrow  - Access generated command from history"; echo "  tg!       - Execute last generated command"; echo "  tg?       - Show last generated command"; echo "  Ctrl+T    - Interactive mode (with execution prompt)"'

# Alternative approach: Create a more interactive version
alias termgpt-interactive 'echo -n "termgpt> " ; set _tg_prompt = "$<" ; if ( "$_tg_prompt" != "" ) then ; set _tg_result = `termgpt -p "$_tg_prompt"` ; if ( "$_tg_result" != "" ) then ; echo "Generated: $_tg_result" ; echo -n "Execute? [y/N] " ; set _tg_exec = "$<" ; if ( "$_tg_exec" =~ [Yy]* ) eval "$_tg_result" ; endif ; endif ; endif'

# Bind Ctrl+T as an alternative for the interactive version
bindkey -c "^T" 'termgpt-interactive'

# END termgpt integration

# Userland tool dirs — needed so ssh-launched commands (e.g. mosh-server
# installed via micromamba) are found on $PATH. Missing dirs skipped.
foreach _d ( \
    "$HOME/.local/bin" \
    "$HOME/.local/share/mise/shims" \
    "$HOME/.local/micromamba/envs/dotfiles/bin" \
    "$HOME/.bun/bin" \
)
  if (-d "$_d") set path = ( "$_d" $path:q )
end
unset _d

# Anthropic / Claude Code (non-secret URL + model). API key in secrets.csh.
setenv ANTHROPIC_BASE_URL https://inference-api.nvidia.com/
setenv ANTHROPIC_MODEL 'aws/anthropic/bedrock-claude-opus-4-6[1m]'
setenv CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS 1
setenv CLAUDE_CODE_NO_FLICKER 1
# Advertise truecolor for TUI apps (codex grey input bar etc.).
if (! $?COLORTERM) setenv COLORTERM truecolor

# Headless xterm hosts have no browser; BROWSER=false prevents xdg-open
# from launching anything (does not fix MSAL hang — see bootstrap.sh).
if (-d "/home/scratch.${USER}_gpu") setenv BROWSER false

# Secrets from the private dotfiles-secrets repo (cloned by bootstrap).
if (-r ~/.config/dotfiles-secrets/secrets.csh) source ~/.config/dotfiles-secrets/secrets.csh

# OpenAI-compatible config — same key as Anthropic on the NVIDIA inference gateway.
if ($?ANTHROPIC_API_KEY) setenv OPENAI_API_KEY "$ANTHROPIC_API_KEY"
setenv OPENAI_BASE_URL 'https://inference-api.nvidia.com/v1/'
setenv OPENAI_MODEL 'openai/openai/gpt-5.5'

# zoxide-as-cd: tcsh has no functions/chpwd, so shell out to ~/.local/bin/zcd-csh
# (shipped by dotfiles) and feed the chosen path back to the builtin chdir.
# Also tracks visited dirs so the frecency DB stays current.
if ( -x ~/.local/bin/zcd-csh && { which zoxide >& /dev/null } ) then
    alias cd 'chdir "`~/.local/bin/zcd-csh \!*`" && zoxide add "$cwd" >& /dev/null'
endif

# Two-line prompt that matches the *information* shown by p10k (zsh) and
# starship (bash): user@host, cwd, last-command exit, then the prompt char.
# Pure tcsh sequences only — starship in tcsh leaks nerd-font glyphs that
# render as "??" in the terminal because tcsh mis-tracks their width.
if ( $?tcsh ) then
    set prompt="%B%n@%m%b  %~  [exit %?]\\
%# "
endif
