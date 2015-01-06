#!/bin/bash

#Where you want the archive to be stored locally (absolute path).
ARCHIVEDIR=~/.arc

#The list of what passes for metadata.
INDEX=$ARCHIVEDIR/.index.csv


bold=`tput bold`
normal=`tput sgr0`

if [ -z $EDITOR ]
then
 EDITOR=nano
fi

arcadd(){
    #`arcadd` Takes a URL, downloads and processes the document.
    # This includes extraction of text and provision for a comments file.
    TMPDIR=$ARCHIVEDIR/.temp
    INPAGE=$ARCHIVEDIR/index.html
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
            title=$(grep "<title" $INFILE | head -1 |  sed 's/.*<title[^>]*>\([^<]*\)<\/title>.*/\1/')
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

    #Move files into dir
    NEWDIR=$ARCHIVEDIR/$id
    mkdir $NEWDIR
    cp $INFILE $NEWDIR/source.$ext
    cp $TXTFILE $NEWDIR/plaintext.txt
    cp $COMFILE $NEWDIR/comment.md
    arcrender $id $title

    #Update the index
    dated=$(date -I)
    echo "$id,$dated,\"$title\",\"$URL\"" >> $INDEX
    echo "File archived."
    echo "Title: $title"
    echo "Date: $dated"
    echo "ID: $id"
    echo "Origin: $URL"

    #Write .md from csv.
    mdfile=index.md
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
    matches=$(grep $1 $INDEX | cut -f 1 -d ,)
    rcount=$(echo $matches | wc -w)
    if [ $rcount>1 ] 
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

arcidtitle(){
    #Searches for a presentation title for an ID.
    grep $1 $INDEX | cut -f 3 -d , | sed 's/"//g'
}

arcgrep(){
 matches=$(grep -lm 1 $1 $ARCHIVEDIR/*/plaintext.txt | sed 's/.*\/\([^\/]*\)\/plaintext.txt/\1/')
 rcount=$(echo $matches | wc -w)
 echo ${bold}$rcount matches found: ${normal}
 echo ""
 for id in $matches
 do
    title=$(arcidtitle $id)
    echo " ${bold}$title${normal}"
    echo " "$(grep -hA 2 -m 3 $1 $ARCHIVEDIR/$id/plaintext.txt)
    echo " "
 done
}

arcopen(){
    id=$(arcidpartmatch $1)
    echo $id
    mimeopen $ARCHIVEDIR/$id/source.*
}

arcbrowse(){
    id=$(arcidpartmatch $1)
    title=$(arcidtitle $id)
    arcrender $id $title
    xdg-open $ARCHIVEDIR/$id/index.html
}

arccomment(){
    id=$(arcidpartmatch $1)
    title=$(arcidtitle $id)
    echo $id
    $EDITOR $ARCHIVEDIR/$id/comment.md
    arcrender $id $title
}

arcrender(){
    id=$1
    title=$2
    mdfile=$ARCHIVEDIR/$id/comment.md
    render=$ARCHIVEDIR/$id/index.html
    echo -e "<html>\n<head><title>$title</title>\n<link rel='stylesheet' type='text/css' href='../styleless.css'/>\n</head><body>" > $render
    markdown $mdfile >> $render
    echo -e "<a href='../index.html'>[home]</a>\n</body>\n</html>" >> $render
}

#Farm out subcommands.
case $1 in
    "add")
    arcadd $2;;
    "search"|"grep")
    arcgrep $2;;
    "open"|"view")
    arcopen $2;;
    "comment")
    arccomment $2;;
    "browse")
    arcbrowse $2;;
    *)
    echo "Not Implemented";;
esac
