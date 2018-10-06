#!/bin/sh
rprint() { for _ in $(seq "$1"); do echo -n "$2"; done }


# course table helper function
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
    for cos in $course_table; do
        len=$(echo "$cos" | cut -d'@' -f4 | wc -c)
        col=$(( (len + CW - 1) / CW ))
        CH=$(( CH > col ? CH : col ))
    done
}

parse_cos_table() {
    # parse ${course_table} into ${cos_table}
    for cos in $course_table; do
        name=$(echo "$cos" | cut -d'@' -f4)
        time=$(echo "$cos" | cut -d'@' -f2)
        time=$(echo "$time" | sed -e 's/\(.\)/\1 /g')
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
    for cos in $cos_table; do
        name=$(echo "$cos" | grep "^$1" | cut -d'@' -f2)
        [ -z "$name" ] || return 0
    done
}

load_display_table() {
    calculate_CH
    parse_cos_table
    display_table=$(draw_table)
}

# add course helper function
check_collision() {
    time=$(echo "$1" | cut -d'@' -f2) 
    time=$(echo "$time" | sed -e 's/\(.\)/\1 /g')
    d='0'
    for t in $time; do
        case $t in
            (*[!0-9]*|'')
                has_coll=$(echo "$cos_table" | grep "$d$t@")
                [ -z "$has_coll" ] || break;;
            (*) d=$t;;
        esac
    done
    if [ -n "$has_coll" ]; then
        name=$(echo "$1" | cut -d'@' -f4 | sed -e 's/~/ /g') 
        collision="Collision: $d$t\n$name"
    fi
}


# dialog helper function
dialog_main() {
    tmpfile=$(mktemp /tmp/hw2)
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
        load_display_table
    fi
}

dialog_collision() {
    [ -z "$1" ] && return 0
    dialog --msgbox "$1" 6 "$W"
}

dialog_option() {
    return 0
}

# config helper function
load_all_course() {
    all_course=$(./download.sh)
}

load_course_table() {
    course_table=$(tail -n 5 tmp.out)
}

parse_course_menu() {
    for cos in $all_course; do
        cid=$(echo "$cos" | cut -d'@' -f 1)
        entry=$(echo "$cos" | awk -F '@' '{
            printf "%s %s - ", $2, $3
            $0 = $4
            gsub(/~/, " ")
            print $0
        }')
        course_menu="$course_menu $cid \"$entry\""
        all_course_count=$(( all_course_count + 1 ))
    done
}

# global info
W=$(tput cols)
H=$(tput line)

DAY='Mon Tue Wed Thu Fri '
DAY_N='1 2 3 4 5'
TIME='A B C D E F G H I J K'
CW=$(( W / (${#DAY} / 4) - 3 ))
CH=1

#DAY='Mon Tue Wed Thu Fri Sat Sun '
#TIME='M N A B C D X E F G H Y I J K L'

# all
all_course=''
all_course_count=0
course_menu=''
# user
course_table=''
cos_table=''
display_table=''

# main
load_all_course
parse_course_menu

load_course_table
load_display_table

while true; do
    dialog_main
    case $? in
        0)
            while true; do
                dialog_course
                dialog_collision "$collision"
                [ -z "$collision" ] && break
            done;;
        3)
            dialog_option
            ;;
        2|255)
            exit 0
            ;;
    esac
done
