#Arc

Arc is designed for saving and annotating things. Specifically, interesting texts found online.

Usage:

```{bash}
arc add <url>
```
should cause the system to 
	1. download the specified file, 
	2. detect the mimetype
	3. extract the text into a .txt version for searc purposes
	4. extract or guess at the title
	5. open $EDITOR with the title pre-loaded for editing, and ready to accept annotation
	6. save the article under the specified title id, storing a log in a master file

```{bash}
arc search <txt>
```
should cause the system to do a full-text search for content which matches (via `grep`)


```{bash}
arc open <id>
```
should cause the system to open the specified text in the appropriate program, where <id> can
be a partial id, the system soft-matching to the simplest choice for the input

```{bash}
arc comment <id>
```
should cause the system to open the comments file for editing, and render it on closing.

```{bash}
arc browse <id>
```
should cause the system to open the annotations for the  specified text in the browser


```{bash}
arc sync <location> <cmd>
```
should cause the system to sync its contents with a specified remote repository, using
`rsync -e "<cmd>"` to make the connection (these variables can be edited directly at the
top of the script.)

