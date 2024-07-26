#!/usr/bin/env bash

# 1a. read in the retroarch.cfg INI file
# 1b. prompt for the Login Server URL if it's not already set
#     in the INI file
# 2. display a dialog showing the current login status
# 3. run a `curl` command in the background that waits
#    for a response from the Login Server instance
# 4a. set up a new user profile if the ID is new
# 4b. update the savefile and statestate directory entries
#     pointing to the logged in user's dirs
user=$(stat -c "%U" "$HOME")
group=$(stat -c "%G" "$HOME")

pretty_path() {
  dir="$1"
  if [ ! -d "$1" ]; then
    dir="$(dirname "$dir")"
  fi
  pushd "$dir" > /dev/null
  with_tilde=$(dirs +0)
  popd > /dev/null
  if [ ! -d "$1" ]; then
    with_tilde="$with_tilde/$(basename "$1")"
  fi
  echo "$with_tilde"
}

error() {
  echo "$@" >&2
}

source "$HOME/RetroPie-Setup/scriptmodules/inifuncs.sh"
if [ $? -ne 0 ]; then
  dialog \
    --colors \
    --ok-label "Close" \
    --title "Command failed" \
    --msgbox "\nsource $HOME/RetroPie-Setup/scriptmodules/inifuncs.sh\n" \
    0 0
  exit 1
fi

if [[ -z "$CONFIG_FILE" ]]; then
  CONFIG_FILE="/opt/retropie/configs/all/retroarch.cfg"
fi
iniConfig " = " '"' "$CONFIG_FILE"

trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT
export TOP_PID=$$

# "save_profiles_directory" is the directory where user profiles will be
# stored, and symlinks to the current active profile will be kept as well
iniGet "save_profiles_directory"
if [[ -z "$ini_value" ]]; then
  PROFILES_ROOT="$HOME/RetroPie/save-profiles"
  iniSet "save_profiles_directory" "$PROFILES_ROOT"
else
  PROFILES_ROOT="$ini_value"
fi

# Function to create a new user
create_user() {
  TMP_OUTPUT=$(mktemp)
  dialog --inputbox "Enter the new user's name:" 0 0 2>"$TMP_OUTPUT"
  rc=$?
  if [ $rc -ne 0 ]; then
    exit 1
  fi
  NAME=$(cat "$TMP_OUTPUT")
  rm "$TMP_OUTPUT"

  PROFILE_ROOT="$PROFILES_ROOT/$(echo $NAME | tr '[:upper:]' '[:lower:]' | sed 's/ /_/g')"
  USER_SAVE_FILES="$PROFILE_ROOT/save-files"
  USER_SAVE_STATES="$PROFILE_ROOT/save-states"

  mkdir -p "$USER_SAVE_FILES" "$USER_SAVE_STATES"
  chown -R $user:$group "$PROFILES_ROOT" 2>/dev/null

  iniSet "savefile_directory" "$USER_SAVE_FILES"
  iniSet "savestate_directory" "$USER_SAVE_STATES"
  iniSet "save_profiles_current_id" "$ID"
  iniSet "save_profiles_current_name" "$NAME"

  dialog \
    --colors \
    --ok-label "Close" \
    --title "User Created" \
    --msgbox "\nSuccessfully created user:\n\n    \Zb$NAME\ZB\n\nProfile Directory: $(pretty_path "$PROFILE_ROOT")\n\n" \
    0 0
  restart_emulationstation
}
select_user() {
  PROFILES=($(ls -d $PROFILES_ROOT/*/ | xargs -n 1 basename))
  PROFILE_MENU=()
  for PROFILE in "${PROFILES[@]}"; do
    PROFILE_MENU+=("$PROFILE" "")
  done

  TMP_OUTPUT=$(mktemp)
  dialog --menu "Select a user:" 0 0 0 "${PROFILE_MENU[@]}" 2>"$TMP_OUTPUT"
  rc=$?
  if [ $rc -ne 0 ]; then
    exit 1
  fi
  SELECTED_PROFILE=$(cat "$TMP_OUTPUT")
  rm "$TMP_OUTPUT"

  PROFILE_ROOT="$PROFILES_ROOT/$SELECTED_PROFILE"
  USER_SAVE_FILES="$PROFILE_ROOT/save-files"
  USER_SAVE_STATES="$PROFILE_ROOT/save-states"

  NAME=$(echo $SELECTED_PROFILE | sed 's/_.*//')
  ID=$(echo $SELECTED_PROFILE | sed 's/.*_//')

  iniSet "savefile_directory" "$USER_SAVE_FILES"
  iniSet "savestate_directory" "$USER_SAVE_STATES"
  iniSet "save_profiles_current_id" "$ID"
  iniSet "save_profiles_current_name" "$NAME"

  dialog \
    --colors \
    --ok-label "Close" \
    --title "User Selected" \
    --msgbox "\nSuccessfully logged in as:\n\n    \Zb$NAME\ZB\n\nProfile Directory: $(pretty_path "$PROFILE_ROOT")\n\n" \
    0 0

  restart_emulationstation
}

# display the current status info dialog and login URL




restart_emulationstation(){
	killall emulationstation
	/bin/sh /opt/retropie/supplementary/emulationstation/emulationstation.sh
}


# Main Menu
while true; do
  dialog --menu "Choose an action:" 0 0 0 \
    1 "Select Existing User" \
    2 "Create New User" 2> /tmp/menuitem.$$
  menuitem=$(< /tmp/menuitem.$$)
  rm /tmp/menuitem.$$

  case $menuitem in
    1)
      select_user
      ;;
    2)
      create_user
      ;;
    *)
      break
      ;;
  esac
done
