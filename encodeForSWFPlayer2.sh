#!/bin/bash

#Container="flv"
Container="mp4"
Bitrate="700k"
Temporary_Dir="/tmp/"
stop_file="enco_stop"
movie_info_file="movie_info_txt"

progress_info_file="${Temporary_Dir}encodeForSWFPlayer_Progress_info"
Thread_Count=4
is_working_eternally="true"
thumb_prefix="ZIV2Thumb_"

function echoHelp()
{
	echo -e "USAGE
	$0 --help
	$0 --stop-enco
	$0 [-i directory] [-o directory] [-f file] [-e] [-t count] [-p string]

	-i directory
		This specifies the directory for src files.

		Don't include a file except the animation in the src directory.
		All the files in src directory are deleted.

	-o directory
		This specifies the directory for the files which you want to encode.

	-f
		This specifies the file to write in encoding information.

	-p string
		Thumbnail file prefix

	-e
		This program continue working eternally till executing stop-enco without e option.

	-t thread cont

	-d
		High Definition

default setting
    thread_count : ${Thread_Count}
    stop-enco file : ${Temporary_Dir}${stop_file}
    progress_info_file : ${progress_info_file}"
}

function checkEnd()
{
	if [ -e "${Temporary_Dir}${stop_file}" ];then
		rm -f "${progress_info_file}"
		rm -f "${Temporary_Dir}${stop_file}"
		exit 0
	fi
}



if [ $# -le 1 ];then
	if [ $# -eq 0 ];then
		echoHelp
	elif [ "$1" = '--help' ];then
		echoHelp
	elif [ "$1" = '--stop-enco' ];then
		touch "${Temporary_Dir}${stop_file}"
	else
		echoHelp
	fi
	exit 0;
fi
if [ $# -ge 2 ];then
	curdir="`pwd`"
	input_dir="$curdir"
	output_dir="$curdir"
	thumb_dir="$curdir"
	progress_info_file="${Temporary_Dir}encodeForSWFPlayer_Progress_info"
	is_working_eternally="true"
	Thread_Count=3
	all_yes="no"
	hd="false"

	while getopts i:o:f:t:p:e:y:d OPT
	do
		case $OPT in
			"i" ) input_dir="$OPTARG" ;;
			"o" ) output_dir="$OPTARG" ; thumb_dir="$OPTARG" ;;
			"f" ) progress_info_file="$OPTARG" ;;
			"e" ) is_working_eternally="false" ;;
			"t" ) Thread_Count="$OPTARG" ;;
			"p" ) thumb_prefix="$OPTARG" ;;
			"y" ) all_yes="yes" ;;
			"d" ) hd="true" ;;
			* ) echoHelp ; exit 1 ;;
		esac
	done
fi

if [ -e "${progress_info_file}" ];then
	echo "Already been executing this program."
	echoHelp
	exit 0
fi

echo -e -n "execute by following settings
    Input directory		$input_dir
    Output directory		$output_dir
    Output Thumbnails		$thumb_dir
    Thumbnail file prefix		$thumb_prefix
    Encoding Information		$progress_info_file
    Thread count		$Thread_Count
    Working eternally		$is_working_eternally
" | column -ts\	
echo -n "Do you want to continue (Y/n)> "
if [ "${all_yes}" = "no" ];then
	read YN
	YN=`echo ${YN} | tr "[A-Z]" "[a-z]"`
	if [ "${YN}" = "n" -o "${YN}" = "no" ];then
		exit
	fi
fi

echo "Waiting next file"
cd "$input_dir"
input_dir="`pwd`/"
IFS_backup=${IFS}
while true
do
	echo "Not encoding" > "${progress_info_file}"
IFS="
"
	#for file in $(ls -utr1)
	#for file in $(find -amin +2 -type f)
	for file in $(find -mmin +2 -type f -exec ls -lu {} \; | sort -k 6,7  | cut -f 8- -d " ")
	do
		IFS=${IFS_backup}
		file=${file#./}
		echo ${file}
		input="${input_dir}${file}"
		output_filename="${file%.*}"
		tmpoutput="${Temporary_Dir}${output_filename}.${Container}"
		output="${output_dir}${output_filename}.${Container}"
		thumb="${thumb_dir}${thumb_prefix}${output_filename}.jpg"
		if [ ! -e "${input}" -o ! -r "${input}" ];then
			break;
		fi

		echo "Start Encode..."
		#sleep 30

		ffmpeg -i "${input}" &> "${Temporary_Dir}${movie_info_file}"
		if [ "${hd}" = "false" ]; then
		MSIZE_ASPECT=`cat "${Temporary_Dir}${movie_info_file}" | grep "Video:" | awk '
			{
				split($6, ary, '/[x,]/');
				aspect=ary[1] / ary[2];
				if(432 > ary[2])
				{
				}else if(aspect < 1.5)
				{
					print "-s 576x432 -aspect 4:3";
				}else
				{
					print "-s 768x432 -aspect 16:9";
				}
			}
		'`
		else
		MSIZE_ASPECT=`cat "${Temporary_Dir}${movie_info_file}" | grep "Video:" | awk '
			{
				split($6, ary, '/[x,]/');
				aspect=ary[1] / ary[2];
				if(432 > ary[2])
				{
				}else if(aspect < 1.5)
				{
					print "-s 960x720 -aspect 4:3";
				}else
				{
					print "-s 1280x720 -aspect 16:9";
				}
			}
		'`
		fi
		time=(`grep Duration "${Temporary_Dir}${movie_info_file}" | cut -f 4 -d " " | tr -d "," | tr ":" " "`)
		echo \( ${time[0]} \* 60 + ${time[1]} \) \* 60 + ${time[2]}
		totaltime=`echo \( ${time[0]} \* 60 + ${time[1]} \) \* 60 + ${time[2]} | bc`
		#fps=`grep -A 3 Input "${Temporary_Dir}${movie_info_file}" | grep "Video" | sed -e 's/^.*Video: //' -e 's/,//g' | cut -f 4 -d ' '`
		#gop_size=`echo "${fps} * 5 + 0.5" | bc | sed -e 's/\..*//'`

		retv="`grep 'Video: h264' "${Temporary_Dir}${movie_info_file}" | wc -l`"
		reta="`grep 'Audio: libfaad' "${Temporary_Dir}${movie_info_file}" | wc -l`"

		rm "${Temporary_Dir}${movie_info_file}"

		A_OPT="-acodec libfaac -ac 2 -ar 48000 -ab 96k -async 1"
		gop_size="125"
		V_OPT="-vcodec libx264 ${MSIZE_ASPECT} -b ${Bitrate} -r 25 -g ${gop_size} -qmin 18"

		if [ "${MSIZE_ASPECT}" == "" ]; then
			if [ "$retv" != "0" ]; then
				V_OPT="-vcodec copy ${MSIZE_ASPECT}"
			fi
		fi
		if [ "$reta" != "0" ]; then
			A_OPT="-acodec copy"
		fi

		date +'%s' > "${progress_info_file}"

		ext=${input##*.}
		if [ ${ext} != "ts" ]; then
			echo ffmpeg -i "${input}" -y -threads ${Thread_Count} ${V_OPT} ${A_OPT} -f ${Container} "${tmpoutput}" | tee -a "${progress_info_file}"
			nice --adjustment=19 ffmpeg -i "${input}" -y -threads ${Thread_Count} ${V_OPT} ${A_OPT} -f ${Container} "${tmpoutput}" \
				2>&1 | tee -a "${progress_info_file}"
		else
			PERL=/usr/bin/perl
			TSENC=/usr/local/bin/tsencode.pl
			echo $PERL $TSENC "${input}" "${tmpoutput}" 960x720 | tee -a "${progress_info_file}"
			nice --adjustment=19 $PERL $TSENC "${input}" "${tmpoutput}" 960x720 \
				2>&1 | tee -a "${progress_info_file}"
		fi
		if [ ! -s "${tmpoutput}" ];then
			touch "${output}.encode_failed"
		else
			MP4Box -inter 500 "${tmpoutput}" -out "${output}"
			#mv -v "${tmpoutput}" "${output}"
			ffmpeg -ss 5 -vframes 1 -i "${output}" -y -f image2 ${MSIZE_ASPECT} -an "${thumb}"
			rm -f "${input}"
			chown www-data:www-data "${output}" "${thumb}"
		fi

		rm -f "${tmpoutput}"
		echo "Not encoding" > "${progress_info_file}"
		checkEnd
		echo "Waiting next file"
	done
	if [ "${is_working_eternally}" = "false" ];then
		rm -f "${progress_info_file}"
		exit 0;
	fi
	#for i in $(seq 30 -1 0)
	#do
	#	checkEnd
		#echo -n -e "next ${i}sec   \r"
		sleep 30
		checkEnd
	#done
done
