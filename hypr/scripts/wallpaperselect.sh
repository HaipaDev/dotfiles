#!/usr/bin/env sh

# set variables
ScrDir=`dirname "$(realpath "$0")"`
RofiConf="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/wallpaperselect.rasi"
wallPath="${XDG_CONFIG_HOME:-$HOME/.config}/swww"
thumbPath="${wallPath}/.thumbnails"
disabledPath="${wallPath}/.disabled"

change_color_scheme=true
force_change_color_to_default=true
random_include_gifs=false

# Create thumbnail directory if it doesn't exist
mkdir -p "${thumbPath}"

# scale for monitor x res
x_monres=$(hyprctl -j monitors | jq '.[] | select(.focused==true) | .width')
monitor_scale=$(hyprctl -j monitors | jq '.[] | select (.focused == true) | .scale' | sed 's/\.//')
x_monres=$(( x_monres * 17 / monitor_scale ))

# set rofi override
elem_border=$(( hypr_border * 3 ))
r_override=""
r_override="element{border-radius:${elem_border}px;} listview{columns:6;spacing:100px;} element{padding:0px;orientation:vertical;} element-icon{size:${x_monres}px;border-radius:0px;} element-text{padding:20px;}"

# generate thumbnail if not exist (for GIFs)
generate_thumbnail() {
  local filepath="$1"
  local filename=$(basename "$filepath")
  local thumbfile="${thumbPath}/${filename%.*}.png"

  # Create a thumbnail if it doesn't already exist
  if [ ! -f "$thumbfile" ]; then
    ffmpeg -y -i "$filepath" -vf "thumbnail,scale=${x_monres}:-1" -frames:v 1 "$thumbfile" >/dev/null 2>&1
  fi

  echo "$thumbfile"
}

# launch rofi menu
RofiSel=$((
  echo "Random Select" && \
  find -L "${wallPath}" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) ! -path "${thumbPath}/*" ! -path "${disabledPath}/*" -exec basename {} \; | sort
) | while read rfile
do
	if [[ "$rfile" == "Random Select" ]]; then
		echo -en "Random Select\n"
	else
	  if [[ "$rfile" == *.gif ]]; then
	    thumb=$(generate_thumbnail "${wallPath}/${rfile}")
	    echo -en "$rfile\x00icon\x1f${thumb}\n"
	  else
	    echo -en "$rfile\x00icon\x1f${wallPath}/${rfile}\n"
	  fi
	fi
done | rofi -dmenu ${RofiSel} -theme-str "${r_override}" -config "${RofiConf}" -select "${currentWall}")

# handle random selection
if [ "$RofiSel" == "Random Select" ]; then
  if [ "$random_include_gifs" == true ]; then
  	selected=$(find -L "${wallPath}" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) ! -path "${thumbPath}/*" ! -path "${disabledPath}/*" | shuf -n 1)
  else
  	selected=$(find -L "${wallPath}" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) ! -path "${thumbPath}/*" ! -path "${disabledPath}/*" | shuf -n 1)
  fi
  echo "$selected"
else
  selected="${wallPath}/${RofiSel}"
fi

# apply wallpaper
if [ ! -z "${RofiSel}" ] ; then
  already_set=false
  if [ "$RofiSel" != "Random Select" ]; then
  	selected="${wallPath}/${RofiSel}"
  fi
  echo "$selected"

  current_wallpaper=$(cat "${wallPath}/current.set")
  _selected=$(cat "$selected")
  if [ "$_selected" != "$current_wallpaper" ]; then
	  swww img $selected \
	    --transition-type "wipe" \
	    --transition-duration 2
  else
      echo "Wallpaper is already set to: $selected"
      already_set=true
	  # swww img $current_wallpaper
  fi

  rm "${wallPath}/current.set"
  # rm "/usr/share/sddm/themes/corners/backgrounds/background.png"

  ln -s $selected "${wallPath}/current.set"
  # ln -s $selected "/usr/share/sddm/themes/corners/backgrounds/background.png"

  # Check for accent color file
  if [ "$change_color_scheme" == true ]; then
  	  base_name="${selected%.*}"
  	  accent_file="${base_name}_accent.txt"
   	  if [ ! -f "$accent_file" ]; then
  	  	accent_file="${base_name}_color.txt"
  	  fi
  	  if [ ! -f "$accent_file" ]; then
	  	accent_file="${base_name}.txt"
	  fi
	  
	  if [ -f "$accent_file" ]; then
	  	echo "$accent_file"
	    # Read the first line (the hex color)
	    accent_color=$(head -n 1 "$accent_file")
	    
	    # call script to change the accent color
	    $HOME/change-main-accent.sh "$accent_color"
	  else
		  if [ "$force_change_color_to_default" == true ]; then
		  	$HOME/change-main-accent.sh
		  fi
	  fi

	  if pgrep -x "dunst" > /dev/null; then
	    if [ already_set == false ]; then
	  	    dunstify "Changed Wallpaper to ${RofiSel}" -a "Wallpaper" -i "${wallPath}/${RofiSel}" -r 91190 -t 2200
	  	fi
	  else
	  	echo "dunst is not running, skipping notif"
	  fi
	fi
fi
