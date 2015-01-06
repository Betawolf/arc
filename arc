#!/bin/bash


#Where you want the archive to be stored locally (absolute path).
ARCHIVEDIR=~/.arc
#The list of what passes for metadata.
INDEX=$ARCHIVEDIR/.index.csv

arcadd(){
    TMPDIR=$ARCHIVEDIR/.temp
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
        "text/plain")
            #Already text, so source is just duplicate.
            ext=txt
            title=$(head -1 $INFILE)
            cp $INFILE $TXTFILE;;
        "text/html")
            #Webpage, hopefully with all the content. Transform to markdownish.
            ext=html
            title=$(grep "<title" $INFILE | head -1 |  sed 's/.*<title[^>]*>\([^<]*\)<\/title>.*/\1/')
            html2text $INFILE > $TXTFILE;;
        "application/pdf")
            #PDF.
            ext=pdf
            title=$(pdfinfo $INFILE | grep 'Title:' | sed 's/Title:[ ]*\(.*\)/\1/')
            pdftotext $INFILE $TXTFILE;;
        *) 
            #Not sure, don't know how to extract info.
            ext=''
            title=''
            touch $TXTFILE
    esac

    #Create template for comment file.
    echo "#$title" > $COMFILE
    echo "> The best guess about the file's title is above. This is used to form the ID." >> $COMFILE
    echo "> This is the comments file. Remove any lines below you don't want to quote." >> $COMFILE
    echo "" >> $COMFILE
    echo "" >> $COMFILE
    awk '{printf "> %s\n", $0}' < $TXTFILE >> $COMFILE

    #Allow user to edit comments + title
    $EDITOR $COMFILE

    #New title
    title=$(head -1 $COMFILE | sed 's/^#//')

    #Form ID string
    id=$(echo $title | tr '[:upper:]' '[:lower:]' | tr '[:punct:]|[:blank:]' '-' | sed 's/-*$//')

    #Move files into dir
    NEWDIR=$ARCHIVEDIR/$id
    mkdir $NEWDIR
    cp $INFILE $NEWDIR/source.$ext
    cp $TXTFILE $NEWDIR/plaintext.txt
    cp $COMFILE $NEWDIR/comment.md

    #Update the index
    dated=$(date -I)
    echo "$id,$dated,\"$title\",\"$URL\"" >> $INDEX
    echo "File archived."
    echo "Title: $title"
    echo "Date: $dated"
    echo "ID: $id"
    echo "Origin: $URL"
}

case $1 in
    "add")
    arcadd $2;;
    *)
    echo "Not Implemented";;
esac
