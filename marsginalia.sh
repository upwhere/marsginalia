#!/usr/bin/bash
##########################
# This project is just a working concept,
# it holds no licences whatsoever. If it
# somehow is of use to you in any way, do
# whatever you like with it.
# (Public domain)
##########################

readonly MARSDOMAIN='http://www.mars-one.com/'
readonly FAQDIR='/en/faq-en/'
readonly MISSIONDIR='/en/mission/'
readonly NEWSDIR='/en/mars-one-news/'
readonly PRESS_RELEASEDIR='/en/mars-one-news/press-releases/'

readonly DO_EXTRACT_ARTICLE="sed -n /<article/,/<\\/article>/{p}"
readonly DO_EXTRACT_ARTICLE_URLS="sed -n /<article/,/<\\/article/{s/href/\nhref/g;p}"
readonly DO_EXTRACT_URL_LIST="sed -n /<ul/,/<\\/ul>/{s/href/\nhref/g;p}"

readonly COMMENTSDIR='./comments/'
readonly COMPILATION=${1:-'marginalia.html'}
readonly PIPELINE='-' # wget's output document into pipe

readonly sum404=$(wget --quiet --output-document=$PIPELINE $MARSDOMAIN"/en/404" | $DO_EXTRACT_ARTICLE | md5sum $PIPELINE)

## print $@ inside an SGML comment
function inSGML { echo "<!--$@ -->";}

## convert the relative URL in $1 into a comment file path
function commentpath { echo $COMMENTSDIR${1#/en/}".html"; }

##
## get the comment for $1
## checks $2 as md5sum for changes
## stores the comment in $comment
##
function getcomment
{
	file=$(commentpath "$1")
	# check if file exists usefully
	if [ -r "$file" ]; then
		# compare cheksum to the one at end of comment
		if [ "$2" != "$(
				tail -n 1 $file |
				# strip html comment from md5sum output
				cut -b 5-39
				)" ]; then
			if [ -L "$file" ]; then
				printf "	article no longer matches md5 of symlinked %s" "$file"
				unlink $file
			else
				echo "	it has updated! :o"
			fi
			# save a new checksum
			inSGML "$2" >> $file
		fi
		#else file has not changed, all is good.
	else
		# no comments, produce empty comment, store hash
		printf "	new %s!? :o" $file
		inSGML "$2" >> $file
	fi
	comment=$(<$file)
}

##
## include the FAQ
##
function include_faq
{
	# grab the FAQ entry list from its main page
	entries=$(
		wget --quiet $MARSDOMAIN$FAQDIR --output-document=$PIPELINE |
		$DO_EXTRACT_ARTICLE |
		$DO_EXTRACT_URL_LIST |
		grep href |
		sed "{s/.*${FAQDIR//\//\\/}// ; s/\(\(\w*[-\/]\?\)*\).*/\1/}"
		)

	# grab the article from each faq entry
	for entry in $entries; do
		printf "trying %s" "$entry" >&2

		article=$(wget --quiet --output-document=$PIPELINE $MARSDOMAIN$FAQDIR$entry | $DO_EXTRACT_ARTICLE)

		getcomment $entry "$(md5sum $PIPELINE <<< "$article")"

		if ! [ -L $(commentpath "$entry") ]; then
			printf "<tr><td class= 'article' >%s</td> <td class= 'comment' ><article>%s</article></td></tr>" "$article" "$comment" >> $COMPILATION
		fi
	done
}

##
## takes an array of relative URLs to be included
##
function include_children
{
	for child in $@; do
		article=$(wget --quiet --output-document=$PIPELINE $MARSDOMAIN$child | $DO_EXTRACT_ARTICLE)
		
		sum=$(md5sum $PIPELINE<<<"$article")
		if [ "$sum" == "$sum404" ]; then
			printf "		child %s not found" "$child"
			continue;
		fi
		printf "		included child %s" "$child"

		getcomment $child "$sum"
		
		# don't include symlinks to articles, they're used to represent alias links
		if ! [ -L $(commentpath "$child") ]; then
			printf "<tr><td class= 'article' >%s</td> <td class= 'comment' ><article>%s</article></td></tr>" "$article" "$comment" >> $COMPILATION
		fi
	done
}

##
## include mission pages and their children
##
function include_mission
{
	readonly STARTPAGE='mission-vision'
	readonly missions=$(
		printf "%s\n%s" "$STARTPAGE" "$(
			wget --quiet --output-document=$PIPELINE $MARSDOMAIN$MISSIONDIR$STARTPAGE |
	
			# grab the arcticle from the webpage
			sed -n "/<article/,/<\/article/{s/href/\nhref/g;p}" |

			# we only want URLs
			grep href |

			# strip everything but the URL
			sed "{s/.*${MISSIONDIR//\//\\/}// ; s/\(\(\w*[-\/]\?\)*\).*/\1/}" |

			# remove duplicates
			sort -u
			)"
		)


	for mission in $missions; do
		printf "including: %s" "$mission" >&2

		article=$(wget --quiet --output-document=$PIPELINE $MARSDOMAIN$MISSIONDIR$mission | $DO_EXTRACT_ARTICLE)

		getcomment $mission "$(md5sum $PIPELINE<<<"$article")"

		echo "<tr><td class= "article" >$article</td> <td class= 'comment' ><article>$comment</article></td></tr>" >> $COMPILATION

		include_children $(
			# make the urls easily parsable
			sed "{s/href/\nhref/g}" <<< $article |
			# discard everything else
			grep href |
			# grab the relative url
			sed "{s/.*href=\"// ; s/http:\/\/mars-one\.com// ; s/\(\(\w*[-\/]\?\)*\).*/\1/}" |
			# discard duplicates
			sort -u |
			# discard links back to siblings
			grep -Fvx "$(
				# make the siblings comparable to the children
				sed "{s/\(\S*\)/${MISSIONDIR//\//\\/}\1/g ; s/\s/\n/g}" <<< $missions
				)"
			)
	done
}

##
## include public press statements
##
function include_press_releases
{
	:
}

##
## include coverage from external press
##
function include_press_coverage
{
	:
}

##
## include press content
##
function include_press
{
	readonly releases=$(
		wget --quiet --output-document=$PIPELINE $MARSDOMAIN$PRESS_RELEASEDIR |
		$DO_EXTRACT_ARTICLE_URLS |
		grep href |
		sed "{s/.*${NEWSDIR//\//\\/}// ; s/\(\(\w*[-\/]\?\)*\).*/\1/}"
		)
	
	printf "neglected %s" "$releases"
}

#
# TODO: include newsmail
#
function include_mail
{
	:
}

##
## TODO: include articles created by the commenter
##
function include_own
{
	:
}

##
## TODO: include space exploration resources
##
function include_resources
{
	# wget http://www.mars-one.com/en/mars-one-news/resources
	:
}

##
## prepare output
##
echo "<!DOCTYPE html>
<html lang= 'en-GB' >
	<head>
		<title>Notes</title>
		<meta description= 'Marginal notes on the mars-one mission' />
		<meta charset='utf-8' />
		<base href= '$MARSDOMAIN' />
		<link rel= 'StyleSheet' type= 'text/css' href= '/templates/yoo_inspire/css/base.css' />
		<link rel= 'StyleSheet' type= 'text/css' href= '/templates/yoo_inspire/css/layout.css' />
		<link rel= 'StyleSheet' type= 'text/css' href= '/templates/yoo_inspire/css/system.css' />
		<link rel= 'StyleSheet' type= 'text/css' href= '/templates/yoo_inspire/styles/red/css/style.css' />
		<link rel= 'StyleSheet' type= 'text/css' href= '/assets/css/roadmap.css' />
		<style>
			td.article, td.comment
			{
				width:50% ! important;
				overflow: hidden;
			}
			.comment
			{
				background: #225;
				color: #ddd;
				padding: 4em;
			}
			.comment h1
			{
				background: #225;
				color: #ddd;
			}
			table.comments > tbody > tr
			{
				border: solid 1px gray;
			}
		</style>
	</head>
	<body id= 'page' >
		<article class= 'comment' >
			<h1>Marginalia</h1>
			<p>These are my marignal notes on the Mars&ndash;One mission. I use this to organise my thoughts and make sure I got the complete picture. This technique is by far the most effective way for me to accomplish this.</p>
			<p>This page is generated by crawling the <a href= 'http://mars-one.com/' >Mars&ndash;One website</a> and interweaving it with my notes. I wish to apologise for the excessive crawling during development of the script, I hope it wasn&#8217;t too much of a burden on the servers.</p>
		</article>
		<table class= 'comments' ><tbody>" > $COMPILATION

##
## build up content
##
include_mission
#include_faq
#include_press
#include_mail
#include_own

##
## finalize output
##
echo "		</tbody>
		</table>
	</body>
</html>" >> $COMPILATION

