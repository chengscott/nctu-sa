#!/bin/sh
rprint() { for _ in $(seq "$1"); do echo -n "$2"; done }


# display table helper function
draw_table() {
    # draw table using search_cos_table() and
    # ${DAY}, ${DAY_N}, ${TIME}, $W, $H, ${CW}, ${CH}
    echo -n 'x '
    for day in $DAY; do
        echo -n ".$day"
        rprint $(( CW - 2 )) ' '
    done
    echo ''
    for t in $TIME; do
        for line in $(seq "$CH"); do
            tt=$t
            [ "$line" -eq '1' ] || tt='.'
            echo -n "$tt |"
            for d in $DAY_N; do
                search_cos_table "$d$t"
                if [ -z "$name" ]; then
                    rprint "$CW" ' '
                else
                    for i in $(seq "$CW"); do
                        idx=$(( (line - 1) * CW + i ))
                        c=$(echo "$name" | cut -c "$idx" | head -c 1)
                        [ "$c" = '~' ] && c=' '
                        [ -z "$c" ] && c=' '
                        echo -n "$c"
                    done
                fi
                echo -n ' |'
            done
            echo ''
        done
        echo -n '= ='
        for day in $DAY; do
            rprint "$CW" '='
            echo -n ' ='
        done
        echo ''
    done
}

calculate_CH() {
    # calculate column height from ${course_table} into ${CH}
    [ "$show_classroom" = 'on' ] && cf='-f3,4' || cf='-f3'
    for cos in $course_table; do
        len=$(echo "$cos" | cut -d'@' "$cf" | wc -c)
        col=$(( (len + CW - 1) / CW ))
        CH=$(( CH > col ? CH : col ))
    done
}

parse_cos_table() {
    # parse ${course_table} into ${cos_table}
    for cos in $course_table; do
        name=$(echo "$cos" | cut -d'@' -f3,4)
        time=$(echo "$cos" | cut -d'@' -f2 | sed -e 's/\(.\)/\1 /g')
        d='0'
        for t in $time; do
            case $t in
                (*[!0-9]*|'') cos_table="$cos_table $d$t@$name";;
                (*)           d=$t;;
            esac
        done
    done
}

search_cos_table() {
    # search "$1" in ${cos_table}, and result is ${name}
    [ "$show_classroom" = 'on' ] && cf='-f2,3' || cf='-f2'
    for cos in $cos_table; do
        name=$(echo "$cos" | grep "^$1" | cut -d'@' "$cf")
        [ -z "$name" ] || return 0
    done
}

parse_display_table() {
    calculate_CH
    parse_cos_table
    display_table=$(draw_table)
}

# add course helper function
check_collision() {
    time=$(echo "$1" | cut -d'@' -f2 | sed -e 's/\(.\)/\1 /g')
    collision=''
    d='0'
    for t in $time; do
        case $t in
            (*[!0-9]*|'')
                has_coll=$(echo "$cos_table" | grep "$d$t@")
                [ -n "$has_coll" ] && break;;
            (*) d=$t;;
        esac
    done
    if [ -n "$has_coll" ]; then
        name=$(echo "$1" | cut -d'@' -f3 | sed -e 's/~/ /g')
        collision="Collision: $d$t\n$name"
    fi
}

course_state() {
    while true; do
        dialog_course
        dialog_collision "$collision"
        [ -z "$collision" ] && break
    done
}


# dialog helper function
dialog_main() {
    tmpfile=$(mktemp /tmp/hw2.XXX)
    echo "$display_table" > "$tmpfile"
    dialog --ok-label 'Add Course' --extra-button --extra-label 'Option' \
        --help-button --help-label 'Exit' \
        --textbox "$tmpfile" "$H" "$W"
    option=$?
    rm -f "$tmpfile"
    #trap "rm -f $tmpfile" 1 2 3 15
    return "$option"
}

dialog_course() {
    cid=$(eval "dialog --no-tags --menu 'Add Class' $H $W $all_course_count $course_menu" 2>&1 > /dev/tty)
    is_cancel=$?
    if [ "$is_cancel" != "0" ]; then
        collision=""
        return 0
    fi
    for cos in $all_course; do
        [ "$cos" = "${cos#$cid}" ] || break
    done
    check_collision "$cos"
    if [ -z "$collision" ]; then
        course_table="$course_table $cos"
        parse_display_table
        save_config
    fi
}

dialog_collision() {
    [ -z "$1" ] && return 0
    dialog --msgbox "$1" 6 "$W"
}

dialog_option() {
    show_all_day='off'
    show_all_time='off'
    show_classroom='off'
    for opt in $table_option; do
        case $opt in
            1) show_all_day='on';;
            2) show_all_time='on';;
            3) show_classroom='on';;
        esac
    done
    option=$(dialog --no-tags --checklist 'Option' 10 "$W" 3 1 'Show Sat Sun' $show_all_day 2 'Show MNXYL' $show_all_time 3 'Show Classroom' $show_classroom 2>&1 > /dev/tty)
    is_cancel="$?"
    if [ "$is_cancel" = "0" ] && [ "$option" != "$table_option" ]; then
        table_option="$option"
        parse_table_option
        parse_display_table
        save_table_option
    fi
}


# config loading helper function
load_all_course() {
    all_course=$(./download.sh)
}

load_course_table() {
    course_table=''
    if [ -f hw2.cfg ]; then
        course_table=$(tail -n +2 hw2.cfg)
    fi
}

load_table_option() {
    if [ -f hw2.cfg ]; then
        table_option=$(head -n 1 hw2.cfg)
    fi
}


# config saving helper function
save_config() {
    echo "$table_option" > hw2.cfg
    echo '' >> hw2.cfg
    for cos in $course_table; do
        echo "$cos" >> hw2.cfg
    done
}

save_table_option() {
    sed -i -e "1 s/^.*$/$table_option/" hw2.cfg
}

# config paring helper function
parse_course_menu() {
    for cos in $all_course; do
        cid=$(echo "$cos" | cut -d'@' -f 1)
        entry=$(echo "$cos" | awk -F '@' '{
            printf "%s %s - ", $2, $4
            $0 = $3
            gsub(/~/, " ")
            printf $0
        }')
        course_menu="$course_menu $cid \"$entry\""
        all_course_count=$(( all_course_count + 1 ))
    done
}

parse_table_option() {
    DAY='Mon Tue Wed Thu Fri '
    DAY_N='1 2 3 4 5'
    TIME='A B C D E F G H I J K'
    show_classroom='off'
    for opt in $table_option; do
        case $opt in
            1)
                DAY='Mon Tue Wed Thu Fri Sat Sun '
                DAY_N='1 2 3 4 5 6 7'
                ;;
            2)
                TIME='M N A B C D X E F G H Y I J K L'
                ;;
            3)
                show_classroom='on'
                ;;
        esac
    done
    CW=$(( W / (${#DAY} / 4) - 3 ))
}

# global info
W=$(tput cols)
H=$(tput lines)

DAY=''
DAY_N=''
TIME=''
CW=1
CH=1

# config
all_course=''
all_course_count=0
course_menu=''
table_option=''
show_classroom=''
# course
course_table=''
cos_table=''
display_table=''


# main
load_all_course
parse_course_menu

load_table_option
parse_table_option

load_course_table
parse_display_table


while true; do
    dialog_main
    case $? in
        0) course_state;;
        3) dialog_option;;
        2|255) break;;
    esac
done
