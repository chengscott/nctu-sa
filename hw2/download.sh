#!/bin/sh

download_course() {
    curl -o course.json \
         -s 'https://timetable.nctu.edu.tw/?r=main/get_cos_list' \
         --data 'm_acy=107&m_sem=1&m_degree=3&m_dep_id=17&m_group=**&m_grade=**&m_class=**&m_option=**&m_crsname=**&m_teaname=**&m_cos_id=**&m_cos_code=**&m_crstime=**&m_crsoutline=**&m_costype=**'
}

parse_course() {
    tr ',' '\n' < course.json | awk -F ':' '
        BEGIN {
          cos_id = ""
          cos_time = ""
          cos_ename = ""
          cos_class = ""
          flag = 0
        }
        /cos_id/ {
          split($2, res, "\"")
          cos_id = res[2]
          flag = 1
        }
        /cos_time/ {
          split($2, tmp, "\"")
          split(tmp[2], res, "-")
          cos_time = res[1]
          cos_class = res[2]
          flag = 1
        }
        /cos_ename/ {
          split($2, res, "\"")
          $0 = res[2]
          gsub(/ /, "~")
          cos_ename = $0
          flag = 1
        }
        /}/ {
          if (flag == 1)
            print cos_id "@" cos_time "@" cos_ename "@" cos_class
            cos_id = ""
            cos_time = ""
            cos_ename = ""
            cos_class = ""
            flag = 0
        }'
}

# Download course if not exists
[ -f course.json ] || download_course
parse_course
