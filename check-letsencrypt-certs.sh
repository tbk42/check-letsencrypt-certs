#!/bin/bash

usage() {
  local c_reset=$(color "reset");
  local c_blue=$(color "blue");
  local c_dkgray=$(color "dkgray");
  local c_gold=$(color "gold");
  local c_white=$(color "white");
  local c_bold_white="$(color "boldwhite")";

printf "%s\n" ""
printf "%b\n" "${c_gold}Checking LetsEncrypt SSL Certificates${c_reset}"
printf "%b\n" "  ${c_dkgray}$0${c_reset}"
printf "%s\n" ""
printf "%b\n" "  ${c_bold_white}--help ${c_blue}|${c_white} -h ${c_reset} Display this"
printf "%b\n" "  ${c_bold_white}--date ${c_blue}|${c_white} -d ${c_reset} Sort by date (yyyy-mm-dd)"
printf "%b\n" "  ${c_bold_white}--name ${c_blue}|${c_white} -n ${c_reset} Sort by domain name (host.domain.tld)"
printf "%b\n" "  ${c_bold_white}--rev  ${c_blue}|${c_white} -r ${c_reset} Sort by reverse name (tld.domain.host)"
printf "%b\n" "  ${c_bold_white}--asc  ${c_blue}|${c_white} -a ${c_reset} Sort ascending (a-z)"
printf "%b\n" "  ${c_bold_white}--desc ${c_blue}|${c_white} -e ${c_reset} Sort descending (z-a)"
printf "%b\n" "${c_reset}"
}

# -----------------------------------------------------------------------------
# Start Function Library
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# The month2num() function converts months by name to their number. It handles
# both full length names such as "November" as well as three letter code 
# abbriviations like "Nov". It also handles both upper and lower (and mixed) 
# cases. It can output the month number with an optional prepended zero as 
# appropriate such as "05" for months earlier than October.
# 
# Usage: month_num=$(month2num "$month_string" "--prepend_zero")
# -----------------------------------------------------------------------------
function month2num() {
  local month_input="";
  local month=0;
  local leading="";

  if ! [[ -z "$1" ]]; then
    month_input=$(printf "%s\n" "$1" | cut -b1-3 | tr "[:upper:]" "[:lower:]")

    case $month_input in
      "jan") month="1"; ;;
      "feb") month="2"; ;;
      "mar") month="3"; ;;
      "apr") month="4"; ;;
      "may") month="5"; ;;
      "jun") month="6"; ;;
      "jul") month="7"; ;;
      "aug") month="8"; ;;
      "sep") month="9"; ;;
      "oct") month="10"; ;;
      "nov") month="11"; ;;
      "dec") month="12"; ;;
    esac
  fi

  if ! [[ -z "$2" ]]; then
    if [[ "$2" == "--prepend_zero" ]]; then
      leading="0";
    fi
  fi

  if [[ $(( month < 10 )) == "1" ]]; then
    month="$leading""$month";
  fi

  if [[ "$__resultvar" ]]; then
      eval $__resultvar="'$month'";
  else
      printf "%s\n" "$month"
  fi
}

# -----------------------------------------------------------------------------
# The read_x509() function reads and parses x509 certificate files. Pass the 
# full path and filename to the function. Output is a string list in the 
# following format.
# 
# $subject,$expiration_date,$will_expire_yes_no,$fqdn_list
# 
# Usage: cert_info=$(read_x509 "$cert")
# -----------------------------------------------------------------------------
function read_x509() {
  local secinday=86400;
  local cert_file="";
  local cert_data="";

  if ! [[ -z "$1" ]]; then
    cert_file="$1";

    local cert_subject_domain=$(openssl x509 -in "$cert_file" -nocert -subject | cut -d= -f3 | cut -b2-);

    cert_fqdn_list=$(openssl x509 -in "$cert_file" -nocert -ext subjectAltName | cut -s -d, -f1- --output-delimiter=" ");

    local cert_end_date=$(openssl x509 -in "$cert_file" -nocert -enddate | cut -d"=" -f2);
    local cert_end_year=$(printf "%s\n" "$cert_end_date" | rev | cut -d" " -f2 | rev);
    local cert_end_month_string=$(printf "%s\n" "$cert_end_date" | cut -d" " -f1);
    local cert_end_month_num=$(month2num "$cert_end_month_string" "--prepend_zero");
    local cert_end_day=$(printf "%s\n" "$cert_end_date" | rev | cut -d" " -f4 | rev);
    if [[ $(( cert_end_day < 10 )) = 1 ]]; then
      cert_end_day="0""$cert_end_day";
    fi
    local cert_end="${cert_end_year}-${cert_end_month_num}-${cert_end_day}";

    local cert_will_expire=$(openssl x509 -in "$cert_file" -nocert -checkend $(( 14 * $secinday )) | grep --color=no "will expire");
    if ! [[ -z "$cert_will_expire" ]]; then
      cert_will_expire="true";
    else
      cert_will_expire="false";
    fi

    cert_data="$cert_subject_domain,$cert_end,$cert_will_expire,$cert_fqdn_list";
  fi

  if [[ "$__resultvar" ]]; then
      eval $__resultvar="'$cert_data'";
  else
      printf "%s\n" "$cert_data";
  fi
}

# -----------------------------------------------------------------------------
# The build_cert_line() function generates a colorful readout making 
# certificate expiration date and status easy to identify. Pass the full path 
# and filename of the certificate to the function.
# 
# Useage: one_line=$(build_cert_line "$cert_end" "$cert_name" "cert_name_maxlength")
# -----------------------------------------------------------------------------
function build_cert_line() {
  local secinday=86400;
  local domain_maxlength=0;
  
  if ! [[ -z "$1" ]]; then
    if ! [[ -z "$2" ]]; then
      local cert_end="$1";
      local cert_name="$2";

      if ! [[ -z "$3" ]]; then
        domain_maxlength="$3";
      fi

      one_domain="$cert_name";
      after_domain_space="";
      for (( i=0; i<$(( $domain_maxlength - ${#one_domain} )); i++ )); do
        after_domain_space="$after_domain_space ";
      done

      local cert_end_stripped=$(printf "%s\n" "$cert_end" | cut -c5,8 --complement);
      local cert_end_as_sec=$(date +%s -d "$cert_end_stripped");

      local today=$(date +%Y-%m-%d);
      local today_stripped=$(printf "%s\n" "$today" | cut -c5,8 --complement);
      local today_as_sec=$(date +%s -d "$today_stripped");

      local difference_as_days=$(( ($cert_end_as_sec - $today_as_sec) / $secinday ));

      # defaults
        # endcaps are actually a text/foreground item
        # endcap_color use highlight_color
        # icon_color use highlight_text_color (already set)
        # icon_background use highlight_background (already set)
        # middle area with domain text ... same for everyone
        # domain_text do not set, use default
        # domain_background do not set, use default
        # date_text_color use highlight_text (already set)
        # date_background_color use highlight_background (already set)
      local icon="$warning";
      local domain_text="$c_white";
      local domain_background="$c_back_grey_234";
      local highlight_color="$c_yellow";
      local highlight_background="$c_back_yellow";
      local highlight_text="$c_black";
      local post_note=" - manual review";
      local post_command="";

      local time_frames=(); # 0 or less  is red:    expired
      time_frames+=("0");   # 1 - 20     is gold:   renew overdue
      time_frames+=("20");  # 21 - 30    is yellow: renew now
      time_frames+=("29");  # 30 - 31    is purple: pending
      time_frames+=("31");  # 32 or over is green:  good

      if [[ $(( $difference_as_days > $(( ${time_frames[3]} )))) == 1 ]]; then
        # green: 32 or more days, good.
        icon="$good";
        highlight_color="$c_green";
        highlight_background="$c_back_green";
        highlight_text="$c_black";
        post_note="";
      elif [[ $(( $difference_as_days > ${time_frames[2]} )) == 1 ]]; then
        # purple: Between 30 and 32 days, alert period
        icon="$good";
        highlight_color="$c_purple";
        highlight_background="$c_back_purple";
        highlight_text="$c_white";
        post_note=" - Renewal pending within $(( ${time_frames[3]} - ${time_frames[2]} )) days";
      elif [[ $(( $difference_as_days > ${time_frames[1]} )) == 1 ]]; then
        # yellow: Between 21 and 30 days, renew should run
        icon="$warning";
        highlight_color="$c_gold";
        highlight_background="$c_back_gold";
        highlight_text="$c_black";
        post_note=" - Renewal should run now";
      elif [[ $(( $difference_as_days > ${time_frames[0]} )) == 1 ]]; then
        # gold: Between 21 and 0 days, renew is overdue
        icon="$warning";
        highlight_color="$c_yellow";
        highlight_background="$c_back_yellow";
        highlight_text="$c_black";
        post_note=" - Renewal is overdue";
      else
        # red: Zero or fewer days, expired.
        icon="$bad";
        highlight_color="$c_red";
        highlight_background="$c_back_red";
        highlight_text="$c_white";
        post_note=" - Expired";
      fi

      local build="  ";
      build+="${highlight_color}${outter_left_end}";
      build+="${highlight_background}${highlight_text} ${icon} ";
      build+="${domain_background}${highlight_color}${inner_right_end}";

      build+="${domain_background}${domain_text}  ${cert_name}  ${after_domain_space}";

      build+="${domain_background}${highlight_color}${inner_left_end}";
      build+="${highlight_background}${highlight_text} ${cert_end} ${c_reset}";
      build+="${highlight_color}${outter_right_end}";
      build+="${c_reset}";
      build+="${post_note}";
      if ! [[ -z "$post_command" ]]; then
        $post_command
      fi
    fi
  fi

  if [[ "$__resultvar" ]]; then
      eval $__resultvar="'$build'";
  else
printf "%s\n" "$build";
  fi
}

# ----------------------------------------------------
# BlueKnight's Bash Color Library v2.0 - 2023-01-13
# Function color - overyly simple color library but it's a start at one.
# ----------------------------------------------------
function color() {
  local request="";
  local answer="";

  local esc="\e[";
  local m="m";
  local reset="0;39";
  local c256f="38;5;";
  local c256b="48;5;";
  local bold=";1";

  # Color Name Database
  local names=();
  local numbers=();
  numbers+=("16");  names+=("black"); 
  numbers+=("33");  names+=("blue");   
  numbers+=("51");  names+=("cyan");   
  numbers+=("214"); names+=("gold");   
  numbers+=("243"); names+=("gray");   
  numbers+=("234"); names+=("gray234");   
  numbers+=("35");  names+=("green");   
  numbers+=("134"); names+=("pink");   
  numbers+=("57");  names+=("purple");   
  numbers+=("124"); names+=("red");   
  numbers+=("248"); names+=("silver");   
  numbers+=("255"); names+=("white");   
  numbers+=("226"); names+=("yellow");   
  numbers+=("19");  names+=("dkblue");   
  numbers+=("232"); names+=("dkgray");   
  numbers+=("22");  names+=("dkgreen");   
  numbers+=("55");  names+=("dkpurple");   
  numbers+=("52");  names+=("dkred");   
  numbers+=("58");  names+=("dkyellow");   
  numbers+=("39");  names+=("ltblue");   
  numbers+=("255;1"); names+=("boldwhite");   
  numbers+=("000"); names+=("NAME");   

  if ! [[ -z "$1" ]]; then
    request="$1";
  fi

  bold_flag="false";
  back_flag="false";
  if [[ "${request:0:4}" == "bold" ]]; then
    bold_flag="true";
    request="${request:4}";
  elif [[ "${request:0:4}" == "back" ]]; then
    back_flag="true";
    request="${request:4}";
  fi

  for (( i=0; $i<${#names[@]}; i++ )) do
    if [[ "${names[$i]}" == "${request}" ]]; then
      answer="${numbers[$i]}";
      break;
    fi
  done

  if [[ "${request}" == "reset" ]]; then
    answer="${reset}";
  elif [[ "${bold_flag}" == "true" ]]; then
    answer="${c256f}${answer}${bold}";
  elif [[ "${back_flag}" == "true" ]]; then
    answer="${c256b}${answer}";
  else
    answer="${c256f}${answer}";
  fi

  answer="${esc}${answer}${m}";

  if [[ "$__resultvar" ]]; then
      eval $__resultvar="'$answer'";
  else
printf "%s\n" "$answer";
  fi
  return 0;
}
# --- End Function Library ----------------------------------------------------

# -----------------------------------------------------------------------------
# Begin Colors Declaration
# -----------------------------------------------------------------------------
c_reset=$(color "reset");
c_black=$(color "black");
c_blue=$(color "blue");
c_dkgray=$(color "dkgray");
c_gold=$(color "gold");
c_green=$(color "green");
c_purple=$(color "purple");
c_red=$(color "red");
c_white=$(color "white");
c_yellow=$(color "yellow");
c_back_black=$(color "backblack");
c_back_gold=$(color "backgold");
c_back_grey_234=$(color "backgrey234");
c_back_green=$(color "backgreen");
c_back_purple=$(color "backpurple");
c_back_red=$(color "backred");
c_back_yellow=$(color "backyellow");
c_back_white=$(color "backwhite");
c_bold_black=$(color "boldblack");
c_bold_white=$(color "boldwhite");

# --- End Colors Declaration --------------------------------------------------

# -----------------------------------------------------------------------------
# Declare constants
# -----------------------------------------------------------------------------
secinday=86400;
triangle_right="\uE0B0"
triangle_left="\uE0B2"
circle_right="\uE0B4"
circle_left="\uE0B6"
good="✓"
warning="◬"
bad="⬣"
# --- End Constants -----------------------------------------------------------

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
outter_left_end="$circle_left"
outter_right_end="$circle_right"
inner_left_end="$circle_left"
inner_right_end="$circle_right"
certpath="/etc/letsencrypt/live"
# --- End Configuration -------------------------------------------------------

debug="false";
sort_using="name"; # domain name, domain reverse, or date
sort_direction="asc"; # ascending or descending

clp=();
if (( $# > 0 )); then
  for item in $@; do
    clp+=("${item}");
  done
  for (( i=0; i<${#clp[@]}; i++ )) do
    case ${clp[$i]} in
      "--help"|"-h") usage; exit 1; ;;
      "--date"|"-d") sort_using="date"; ;;
      "--name"|"-n") sort_using="name"; ;;
      "--rev"|"-r") sort_using="rev"; ;;
      "--asc"|"-a") sort_direction="asc"; ;;
      "--desc"|"-e") sort_direction="desc"; ;;
      "--debug") debug="true"; ;;
      "-da"|"-ad") sort_using="date"; sort_direction="asc"; ;;
      "-de"|"-ed") sort_using="date"; sort_direction="desc"; ;;
      "-na"|"-an") sort_using="name"; sort_direction="asc"; ;;
      "-ne"|"-en") sort_using="name"; sort_direction="desc"; ;;
      "-ra"|"-ar") sort_using="rev"; sort_direction="asc"; ;;
      "-re"|"-er") sort_using="rev"; sort_direction="desc"; ;;
      *) false; ;;
    esac
  done
fi

# -----------------------------------------------------------------------------
# Main Script Body - slim version, only check/display status of cert
# -----------------------------------------------------------------------------
if ! [[ -d "$certpath" ]]; then
printf "%s\n" "Certificate directory not found: $certpath";
else
  cert_list=$(ls -1R "$certpath/"*"/cert.pem" | sort -f)
  filename_array=();
  cert_name_array=();
  cert_end_array=();
  sort_on_array=();
  domain_maxlength=0;
  if ! [[ -z "$cert_list" ]]; then
    for one_cert in $cert_list; do
      filename_array+=("$one_cert");
      cert_info=$(read_x509 "$one_cert");
      cert_name=$(printf "%s\n" "$cert_info" | cut -d, -f1);
      cert_name_array+=("$cert_name");
      if (( domain_maxlength < ${#cert_name} )); then
        domain_maxlength="${#cert_name}";
      fi
      cert_end=$(printf "%s\n" "$cert_info" | cut -d, -f2);
      cert_end_array+=("$cert_end");
      case "${sort_using}" in
        "name") sort_on_array+=("$cert_name"); ;;
        "rev")  array=("");
                block="";
                for (( i=0; $i<${#cert_name}; i++ )) do
                  letter=${cert_name:$i:1};
                  if ! [[ "$letter" == "." ]]; then
                    block+="$letter";
                  else
                    array+=("$block");
                    block="";
                  fi
                done
                array+=("$block");
                block="";
                new="";
                for (( i=$(( ${#array[@]} - 1 )); $i>0 ; i=$(( $i - 1 )) )) do
                  new+="${array[$i]}";
                  if (( $i > 1 )); then
                    new+=".";
                  fi
                done
                sort_on_array+=("$new");
                ;;
        "date") sort_on_array+=("$cert_end"); ;;
        *)      false; ;;
      esac
    done
  fi

  # Sample data for screen shots
  # debug="false";
  # sort_using="date";
  # sort_direction="asc";
  # domain_maxlength=27;
  # filename_array=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10");
  # cert_name_array=("alpha-alpha-alpha.com" "beta-beta-beta.net" "gamma-gamma-gamma.org" "delta-delta-delta.biz" "epsilon-epsilon-epsilon.com" "eta-eta-eta.tv" "good-good-good.fm" "warning-warning-warning.gg" "danger-danger-danger.us" "expired-expired-expired.fm");
  # cert_end_array=("2023-05-01" "2023-05-01" "2023-05-03" "2023-05-04" "2023-05-05" "2023-05-01" "2023-04-26" "2023-04-20" "2023-04-05" "2023-03-15");
  # case "${sort_using}" in
  #  "date") sort_on_array=(${cert_end_array[@]}); ;;
  #  "name") sort_on_array=(${cert_name_array[@]}); ;;
  #  "rev")  sort_on_array=("com.alpha-alpha-alpha" "net.beta-beta-beta" "org.gamma-gamma-gamma" "biz.delta-delta-delta" "com.epsilon-epsilon-epsilon" "tv.eta-eta-eta" "fm.good-good-good" "gg.warning-warning-warning" "us.danger-danger-danger" "fm.expired-expired-expired"); ;;
  #  *) false; ;;
  # esac

  if [[ "$debug" == "true" ]]; then printf "%s\n" ""; fi;
  if [[ "$debug" == "true" ]]; then printf "%s\n" "Database (${#filename_array[@]})  Sort Request: ${sort_using} ${sort_direction}"; fi;
  for (( i=0; $i<${#filename_array[@]}; i++ )) do
    count=$(( $i + 1 ));
    if (( ${#count} == 1 )); then
      if [[ "$debug" == "true" ]]; then printf "%s\n" "  $count:"; fi;
    elif (( ${#count} == 2 )); then
      if [[ "$debug" == "true" ]]; then printf "%s\n" " $count:"; fi;
    fi
    if [[ "$debug" == "true" ]]; then printf "%s\n" "  ${cert_end_array[$i]}"; fi;
    if [[ "$debug" == "true" ]]; then printf "%s\n" "  ${cert_name_array[$i]}"; fi;
    for (( j=${#cert_name_array[$i]}; $j<$domain_maxlength; j++ )) do
      if [[ "$debug" == "true" ]]; then printf "%s\n" " "; fi;
    done
    if [[ "$debug" == "true" ]]; then printf "%s\n" "  ${sort_on_array[$i]}"; fi;
    if [[ "$debug" == "true" ]]; then printf "%s\n" ""; fi;
  done
  if [[ "$debug" == "true" ]]; then printf "%s\n" ""; fi;

  if (( ${#filename_array[@]} == 0 )); then
printf "%s\n" "";
printf "%b\n" "${c_bold_white}Checking LetsEncrypt SSL Certificates${c_reset}";
printf "%b\n" "  ${c_red}No Certificate Files Found.${c_reset}";
  else
    # bubble sorting
    array_length=${#filename_array[@]};
    swapped=1;
    for (( passno=1; $swapped>0; passno++ )) do
      swapped=0;
      for (( i=0; $i<$array_length; i++ )) do
        indexa=$i;
        indexb=$(( $i + 1 ));
        if (( $indexb < $array_length )); then
          itema=${sort_on_array[$indexa]};
          itemb=${sort_on_array[$indexb]};
          if [[ "$sort_direction" == "desc" ]]; then
            if [[ "${itema}" < "${itemb}" ]]; then
              do_swap="true";
              if [[ "$debug" == "true" ]]; then printf "%s\n" "pass: $passno index: $indexa swap requested on: ${itema} & ${itemb}"; fi;
            fi
          else
            if [[ "${itema}" > "${itemb}" ]]; then
              do_swap="true";
              if [[ "$debug" == "true" ]]; then printf "%s\n" "pass: $passno index: $indexa swap requested on: ${itema} & ${itemb}"; fi;
            fi
          fi
          if [[ "${do_swap}" == "true" ]]; then
            if [[ "$debug" == "true" ]]; then printf "%s\n" " - performing swap"; fi;
            swapped=1;
            temp_filename="${filename_array[$indexa]}";
            filename_array[$indexa]="${filename_array[$indexb]}";
            filename_array[$indexb]="${temp_filename}";
            temp_cert_name="${cert_name_array[$indexa]}";
            cert_name_array[$indexa]="${cert_name_array[$indexb]}";
            cert_name_array[$indexb]="${temp_cert_name}";
            temp_cert_end="${cert_end_array[$indexa]}";
            cert_end_array[$indexa]="${cert_end_array[$indexb]}";
            cert_end_array[$indexb]="${temp_cert_end}";
            temp_sort_on="${sort_on_array[$indexa]}";
            sort_on_array[$indexa]="${sort_on_array[$indexb]}";
            sort_on_array[$indexb]="${temp_sort_on}";
            i=$(( $i - 1 ));
            do_swap="false";
          fi
        fi
      done
    done
\
printf "%s\n" "";
printf "%b" "${c_bold_white}Checking LetsEncrypt SSL Certificate";
    if (( ${#filename_array[@]} > 1 )); then
printf "%b" "s${c_reset} ${c_white}(${c_gold}${#filename_array[@]}${c_white}) ${c_dkgray}(${sort_using} ${sort_direction})${c_reset}";
    fi
printf "%s\n" "";

    for (( i=0; $i<${#filename_array[@]}; i++ )); do
      one_line=$(build_cert_line "${cert_end_array[$i]}" "${cert_name_array[$i]}" "$domain_maxlength");
printf "%b\n" "$one_line";

      if ! [[ -z "$1" ]]; then
        if [[ "$1" == "--renew" ]]; then
          check=$(printf "%s\n" "$one_line" | grep -o "$warning");
          if ! [[ -z "$check" ]]; then
            sudo certbot renew --cert-name ${cert_name_array[$i]} --quiet;
          fi
        fi
      fi
    done
  fi
fi

# exit 0
