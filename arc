#!/bin/bash


#Where you want the archive to be stored locally (absolute path).
ARCHIVEDIR=~/.arc
#Temporary working directory.
TMPDIR=$ARCHIVEDIR/.temp

#A remote backup location (e.g. jim@jimsarchive.net:~/pileofstuff)
#REMOTEDIR=''
#Command to use to connect (e.g. 'ssh -p <port>' for a nonstandard port)
#RSYNCMD=''

#The list of what passes for metadata.
INDEX=$ARCHIVEDIR/.index.csv

bold=`tput bold`
normal=`tput sgr0`

#define $EDITOR if the fools haven't
if [ -z $EDITOR ]
then
 EDITOR=nano
fi

arcadd(){
    #`arcadd` Takes a URL, downloads and processes the document.
    # This includes extraction of text and provision for a comments file.
    INFILE=$TMPDIR/sourcefile
    TXTFILE=$TMPDIR/plaintext.txt
    COMFILE=$TMPDIR/comment.md

    URL=$1


    if [ ! -e $ARCHIVEDIR ]
    then
        echo "Creating archive directory $ARCHIVEDIR"
        mkdir $ARCHIVEDIR
        echo "Creating tmp directory $ARCHIVEDIR"
        mkdir $TMPDIR
        echo "ID,Date,Title,URL" > $INDEX
        echo "Done."
    fi

    #Download file.
    wget -O $INFILE --show-progress $URL


    #Extract the mimetype
    mime=$(mimetype -b $INFILE)

    echo "mimetype: $mime"

    #For each type,
    # - Create 'plaintext.txt'.
    # - extract title according to mimetype.
    case $mime in
        "text/html")
            #Webpage, hopefully with all the content. Transform to gfmish.
            ext=html
            title=$(grep -i "<title" $INFILE | head -1 |  sed 's/.*<title[^>]*>\([^<]*\)<\/title>.*/\1/')
            html2text $INFILE > $TXTFILE;;
        "application/pdf")
            #PDF.
            ext=pdf
            title=$(pdfinfo $INFILE | grep 'Title:' | sed 's/Title:[ ]*\(.*\)/\1/')
            pdftotext $INFILE $TXTFILE;;
        text/*)
            #Already some form of text, so source is just duplicate.
            ext=txt
            title=$(head -1 $INFILE)
            cp $INFILE $TXTFILE;;
        *) 
            #Not sure, don't know how to extract info.
            ext=''
            title=''
            touch $TXTFILE
    esac

    #Create template for comment file.
    echo "#$title" > $COMFILE
    echo "[[source](./source.$ext)]" >> $COMFILE
    echo "" >> $COMFILE
    echo "> The best guess about the file's title is above. This is used to form the ID." >> $COMFILE
    echo "> This is the comments file. Remove any lines below you don't want to quote." >> $COMFILE
    echo "" >> $COMFILE
    awk '{printf "> %s\n", $0}' < $TXTFILE >> $COMFILE

    #Allow user to edit comments + title
    $EDITOR $COMFILE

    #New title
    title=$(head -1 $COMFILE | sed 's/^#//' | sed 's/,/;/g')

    #Form ID string
    id=$(echo $title | tr '[:upper:]' '[:lower:]' | tr '[:punct:]|[:blank:]' '-' | sed 's/-*$//')

    #Update the index
    dated=$(date -I)
    echo $id","$dated",\""$title"\",\""$URL"\"" >> $INDEX
    echo "Title: $(echo $title)"
    echo "Date: $dated"
    echo "ID: $id"
    echo "Origin: $URL"

    #Move files into dir
    NEWDIR=$ARCHIVEDIR/$id
    mkdir $NEWDIR
    cp $INFILE $NEWDIR/source.$ext
    cp $TXTFILE $NEWDIR/plaintext.txt
    cp $COMFILE $NEWDIR/comment.md
    arcrender "$id" "$title"

    #Re-render index page.
    arcmain
    echo "File archived."
}

arcmain(){
    INPAGE=$ARCHIVEDIR/index.html

    #Write .md from csv.
    mdfile=$TMPDIR/index.md
    echo "# arc : contents" > $mdfile
    echo -e "\n\n The arc system stores articles and my associated annotation.\n Below is the current list of articles, with links to the comments.\n" >> $mdfile
    echo "Title|Date|Origin|Comment" >> $mdfile
    echo "---|---|---|---" >> $mdfile
    paste -d'|' <(cut -f3 -d, $INDEX | sed 's/"//g') <(cut -f2 -d, $INDEX) <(cut -f4 -d, $INDEX | sed 's/"//g') <(cut -f1 -d, $INDEX | sed 's/^/[comment](/' | sed 's/$/\/index.html)/') | tail -n +2  | sort -u >> $mdfile 

    #Rebuild the index page.
    echo -e "<html>\n<head><title>arc</title>\n<link rel='stylesheet' type='text/css' href='styleless.css'/>\n</head><body>" > $INPAGE
    gfm $mdfile >> $INPAGE
    echo -e "</body>\n</html>" >> $INPAGE
}

arcidpartmatch(){
    #Turns any part of any csv field into the matching IDs.
    st=$(echo $1 | tr '[:upper:]' '[:lower:]' | tr '[:punct:]|[:blank:]' '-')
    matches=$(grep $st $INDEX | cut -f 1 -d ,)
    rcount=$(echo $matches | wc -w)
    if [ $rcount -gt 1 ] 
    then
        for id in $matches
        do
            echo $id
            break
        done
    else    
        echo $matches
    fi
}

arcsource(){
    #Searches for a source URL for an ID.
    grep "$1" $INDEX | cut -f 4 -d , | sed 's/"\([^"]*\)"/<\1>/g'
}

arcidtitle(){
    #Searches for a presentation title for an ID.
    grep "$1" $INDEX | cut -f 3 -d , | sed 's/"//g'
}

arcgrep(){
    #Prints out a title+snippet for each article with text matching the string input.
    matches=$(grep -lm 1 "$1" $ARCHIVEDIR/*/plaintext.txt | sed 's/.*\/\([^\/]*\)\/plaintext.txt/\1/')
    rcount=$(echo $matches | wc -w)
    echo ${bold}$rcount matches found: ${normal}
    echo ""
    for id in $matches
    do
       title=$(arcidtitle $id)
       echo " ${bold}$title${normal}"
       echo " "$(grep -hA 2 -m 3 "$1" $ARCHIVEDIR/$id/plaintext.txt)
       echo " "
    done
}

arcopen(){
    #opens a file in the appropriate viewer
    id=$(arcidpartmatch $1)
    echo $id
    mimeopen $ARCHIVEDIR/$id/source.*
}

arcbrowse(){
    #gets the browser to open the comments for a file
    id=$(arcidpartmatch $1)
    xdg-open $ARCHIVEDIR/$id/index.html
}

arccomment(){
    #open the comments file for editing
    #then render the result
    id=$(arcidpartmatch $1)
    title=$(arcidtitle $id)
    echo $id
    $EDITOR $ARCHIVEDIR/$id/comment.md
    arcrender "$id" "$title"
}

arcrender(){
    #render a comments file into HTML
    id=$1
    title=$2
    mdfile=$ARCHIVEDIR/$id/comment.md
    render=$ARCHIVEDIR/$id/index.html
    echo -e "<html>\n<head><title>$title</title>\n<link rel='stylesheet' type='text/css' href='../styleless.css'/>\n</head><body>" > $render
    markdown $mdfile >> $render
    echo -e "<a href='../index.html'>[home]</a>\n</body>\n</html>" >> $render
}

arcsync(){
    #sync the archive with a remote directory
    if [ -n "$1" ]
    then
        REMOTEDIR="$1"
        RSYNCMD="$2"
    fi

    #If we have a target, try to sync.
    if [ -n "$REMOTEDIR" ]
    then
        rsync -az -e "$RSYNCMD" $ARCHIVEDIR/* $REMOTEDIR 
    else
        echo "No target directory supplied."
    fi
}

arclist(){
    cut -f 1 -d, $INDEX | tail -n +2
}

#Farm out subcommands.
case $1 in
    "add")
        arcadd "$2";;
    "search"|"grep")
        arcgrep "$2";;
    "open"|"view")
        arcopen "$2";;
    "comment")
        arccomment "$2";;
    "browse")
        arcbrowse "$2";;
    "source")
        arcsource "$2";;
    "sync")
        arcsync "$2" "$3";;
    "refresh")
        arcmain;;
    "list")
        arclist;;
    "test")
        arcidpartmatch "$2";;
    *)
    echo "Usage: arc <cmd> <args>"
    echo -e "Where <cmd> is in:\n\tadd <url>\n\tsearch <string>\n\topen <id>\n\tcomment <id>\n\tbrowse <id>\n\tsync <remotedir> <rsync cmd>\n\trefresh\n\tlist"
    echo -e "It is not usually necessary to write full <id> strings.\n<id> options will operate on the first title matching that substring.";;
esac
